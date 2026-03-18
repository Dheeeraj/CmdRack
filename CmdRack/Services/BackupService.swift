//
//  BackupService.swift
//  CmdRack
//

import Foundation
import Compression

// MARK: - Import mode

enum BackupImportMode: String, CaseIterable {
    case merge
    case replace

    var title: String {
        switch self {
        case .merge:   return "Merge"
        case .replace: return "Replace"
        }
    }

    var subtitle: String {
        switch self {
        case .merge:   return "Keep existing data and add only new commands and events from the backup."
        case .replace: return "Remove all current data first, then restore everything from the backup."
        }
    }

    var icon: String {
        switch self {
        case .merge:   return "arrow.triangle.merge"
        case .replace: return "arrow.triangle.swap"
        }
    }
}

// MARK: - Import result

struct BackupImportResult {
    let commandsImported: Int
    let analyticsEventsImported: Int
    let settingsRestored: Bool
    let pinnedOrderRestored: Bool
    let recentCopiedRestored: Bool

    var summary: String {
        var parts: [String] = []
        if commandsImported > 0 {
            parts.append("\(commandsImported) command\(commandsImported == 1 ? "" : "s")")
        }
        if analyticsEventsImported > 0 {
            parts.append("\(analyticsEventsImported) analytics event\(analyticsEventsImported == 1 ? "" : "s")")
        }
        if settingsRestored { parts.append("settings") }
        if pinnedOrderRestored { parts.append("pinned order") }
        if recentCopiedRestored { parts.append("recent list") }
        if parts.isEmpty { return "No new data imported." }
        return "Restored " + parts.joined(separator: ", ") + "."
    }
}

// MARK: - Backup metadata (quick peek without full decompression)

struct BackupMetadata: Identifiable {
    let id = UUID()
    let deviceName: String
    let exportedAt: Date
    let commandCount: Int
    let analyticsCount: Int
    let version: Int
}

// MARK: - Errors

enum BackupError: LocalizedError {
    case encodingFailed
    case decodingFailed(Error)
    case unsupportedVersion(Int)
    case databaseUnavailable
    case exportFailed(Error)
    case importFailed(Error)
    case compressionFailed
    case decompressionFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode backup data."
        case .decodingFailed(let error):
            return "The file doesn't appear to be a valid CmdRack backup.\n\(error.localizedDescription)"
        case .unsupportedVersion(let v):
            return "This backup was created with a newer version of CmdRack (format v\(v)). Please update the app."
        case .databaseUnavailable:
            return "The local database is not available. Try restarting CmdRack."
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        case .importFailed(let error):
            return "Import failed: \(error.localizedDescription)"
        case .compressionFailed:
            return "Failed to compress backup data."
        case .decompressionFailed:
            return "Failed to decompress backup file. The file may be corrupted."
        }
    }
}

// MARK: - Service

enum BackupService {

    /// File extension for CmdRack backups (a compressed JSON archive).
    static let fileExtension = "cmdrack"

    /// File extension for shareable command packs (no analytics).
    static let shareExtension = "cmds"

    /// Date-stamped default filename, e.g. "CmdRack-2026-03-18.cmdrack"
    static var defaultFileName: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "CmdRack-\(fmt.string(from: Date())).\(fileExtension)"
    }

    /// Default filename for share packs, e.g. "Docker.cmds"
    static func shareFileName(label: String) -> String {
        let safe = label
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .prefix(40)
        let name = safe.isEmpty ? "Commands" : String(safe)
        return "\(name).\(shareExtension)"
    }

    // MARK: - JSON coding helpers

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]          // compact — no prettyPrint since we zip
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Compression (LZFSE via Apple Compression framework)

    /// Compress raw JSON data → small .cmdrack blob.
    private static func compress(_ data: Data) throws -> Data {
        let sourceSize = data.count
        // Worst-case: compressed might be slightly larger than source
        let destinationBufferSize = sourceSize + 64 * 1024
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationBufferSize)
        defer { destinationBuffer.deallocate() }

        let compressedSize = data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Int in
            guard let sourcePointer = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return compression_encode_buffer(
                destinationBuffer, destinationBufferSize,
                sourcePointer, sourceSize,
                nil,
                COMPRESSION_LZFSE
            )
        }

        guard compressedSize > 0 else { throw BackupError.compressionFailed }
        return Data(bytes: destinationBuffer, count: compressedSize)
    }

    /// Decompress .cmdrack blob → raw JSON data.
    private static func decompress(_ data: Data) throws -> Data {
        // Start with 4× buffer; grow if needed
        var destinationBufferSize = data.count * 4
        let maxSize = 256 * 1024 * 1024  // 256 MB safety cap

        while destinationBufferSize <= maxSize {
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationBufferSize)
            defer { destinationBuffer.deallocate() }

            let decompressedSize = data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Int in
                guard let sourcePointer = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_decode_buffer(
                    destinationBuffer, destinationBufferSize,
                    sourcePointer, data.count,
                    nil,
                    COMPRESSION_LZFSE
                )
            }

            if decompressedSize > 0 && decompressedSize < destinationBufferSize {
                return Data(bytes: destinationBuffer, count: decompressedSize)
            }

            // Buffer was too small — double it and retry
            destinationBufferSize *= 2
        }

        throw BackupError.decompressionFailed
    }

    // MARK: - Export

    /// Build a full compressed backup of commands, analytics, settings, pinned order, and recent-copied list.
    static func exportBackup() throws -> Data {
        let repo = CommandRepository()
        let db = DatabaseService.shared

        guard db.isAvailable else { throw BackupError.databaseUnavailable }

        do {
            let commands = try repo.fetchAll()
            let analytics = try db.fetchAllAnalyticsEvents()
            let settings = AppSettings.load()
            let pinnedIDs = PinnedOrderStore.shared.ids
            let recentIDs = RecentCopiedTracker.shared.ids

            let backup = CmdRackBackup.snapshot(
                commands: commands,
                analyticsEvents: analytics,
                settings: settings,
                pinnedOrderIDs: pinnedIDs,
                recentCopiedIDs: recentIDs
            )

            guard let json = try? makeEncoder().encode(backup) else {
                throw BackupError.encodingFailed
            }

            return try compress(json)
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.exportFailed(error)
        }
    }

    // MARK: - Peek (read metadata without full import)

    /// Lightweight envelope that only decodes scalar fields, skipping the large arrays entirely.
    private struct BackupEnvelope: Decodable {
        let version: Int
        let exportedAt: Date
        let deviceName: String
        let commands: [IgnoredItem]
        let analyticsEvents: [IgnoredItem]

        /// A placeholder that accepts any JSON object/value without actually storing it.
        struct IgnoredItem: Decodable {
            init(from decoder: Decoder) throws {
                // Skip all contents — we only need the array count.
                _ = try decoder.singleValueContainer()
            }
        }
    }

    /// Read just the envelope metadata from a .cmdrack file for the import confirmation sheet.
    /// Uses a lightweight decoder that skips the large command/analytics payloads.
    static func peekMetadata(from data: Data) throws -> BackupMetadata {
        let json = try decompress(data)
        let envelope = try makeDecoder().decode(BackupEnvelope.self, from: json)
        return BackupMetadata(
            deviceName: envelope.deviceName,
            exportedAt: envelope.exportedAt,
            commandCount: envelope.commands.count,
            analyticsCount: envelope.analyticsEvents.count,
            version: envelope.version
        )
    }

    // MARK: - Import

    /// Restore data from a previously exported compressed backup.
    @discardableResult
    static func importBackup(from compressedData: Data, mode: BackupImportMode) throws -> BackupImportResult {
        let json: Data
        do {
            json = try decompress(compressedData)
        } catch {
            throw BackupError.decompressionFailed
        }

        let backup: CmdRackBackup
        do {
            backup = try makeDecoder().decode(CmdRackBackup.self, from: json)
        } catch {
            throw BackupError.decodingFailed(error)
        }

        guard backup.version <= CmdRackBackup.currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }

        let repo = CommandRepository()
        let db = DatabaseService.shared
        guard db.isAvailable else { throw BackupError.databaseUnavailable }

        do {
            // --- Commands ---
            if mode == .replace {
                try repo.deleteAll()
            }
            let beforeCount = try repo.fetchAll().count
            try repo.insertBatch(backup.commands)
            let afterCount = try repo.fetchAll().count
            let commandsImported = afterCount - beforeCount

            // --- Analytics ---
            if mode == .replace {
                try db.deleteAllAnalyticsEvents()
            }
            let analyticsBeforeCount = try db.analyticsEventCount()
            try db.insertAnalyticsEvents(backup.analyticsEvents)
            let analyticsAfterCount = try db.analyticsEventCount()
            let analyticsImported = analyticsAfterCount - analyticsBeforeCount

            // --- Settings ---
            DispatchQueue.main.async { backup.settings.save() }

            // --- Pinned order ---
            let pinnedUUIDs = backup.pinnedOrderIDs.compactMap { UUID(uuidString: $0) }
            DispatchQueue.main.async {
                PinnedOrderStore.shared.ids = pinnedUUIDs
                NotificationCenter.default.post(name: .cmdRackPinnedOrderDidChange, object: nil)
            }

            // --- Recent copied ---
            let recentUUIDs = backup.recentCopiedIDs.compactMap { UUID(uuidString: $0) }
            DispatchQueue.main.async {
                RecentCopiedTracker.shared.ids = recentUUIDs
                NotificationCenter.default.post(name: .cmdRackRecentCopiedDidChange, object: nil)
            }

            return BackupImportResult(
                commandsImported: commandsImported,
                analyticsEventsImported: analyticsImported,
                settingsRestored: true,
                pinnedOrderRestored: !pinnedUUIDs.isEmpty,
                recentCopiedRestored: !recentUUIDs.isEmpty
            )
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.importFailed(error)
        }
    }

    // MARK: - Share Packs (commands only, no analytics)

    /// Export a filtered set of commands as a shareable pack.
    static func exportSharePack(commands: [CommandItem], filterDescription: String) throws -> Data {
        let pack = CmdRackSharePack.pack(commands: commands, filterDescription: filterDescription)

        guard let json = try? makeEncoder().encode(pack) else {
            throw BackupError.encodingFailed
        }

        return try compress(json)
    }

    /// Lightweight metadata for share pack import confirmation.
    struct SharePackMetadata: Identifiable {
        let id = UUID()
        let deviceName: String
        let exportedAt: Date
        let filterDescription: String
        let commandCount: Int
        let version: Int
    }

    /// Lightweight envelope for peeking at share pack metadata.
    private struct SharePackEnvelope: Decodable {
        let version: Int
        let exportedAt: Date
        let deviceName: String
        let filterDescription: String
        let commands: [BackupEnvelope.IgnoredItem]
    }

    /// Read metadata from a .cmds file for the import confirmation sheet.
    static func peekShareMetadata(from data: Data) throws -> SharePackMetadata {
        let json = try decompress(data)
        let envelope = try makeDecoder().decode(SharePackEnvelope.self, from: json)
        return SharePackMetadata(
            deviceName: envelope.deviceName,
            exportedAt: envelope.exportedAt,
            filterDescription: envelope.filterDescription,
            commandCount: envelope.commands.count,
            version: envelope.version
        )
    }

    /// Import a share pack, skipping commands whose `command` text already exists locally.
    /// Returns the number of commands actually added.
    @discardableResult
    static func importSharePack(from compressedData: Data) throws -> Int {
        let json: Data
        do {
            json = try decompress(compressedData)
        } catch {
            throw BackupError.decompressionFailed
        }

        let pack: CmdRackSharePack
        do {
            pack = try makeDecoder().decode(CmdRackSharePack.self, from: json)
        } catch {
            throw BackupError.decodingFailed(error)
        }

        guard pack.version <= CmdRackSharePack.currentVersion else {
            throw BackupError.unsupportedVersion(pack.version)
        }

        let repo = CommandRepository()
        guard DatabaseService.shared.isAvailable else { throw BackupError.databaseUnavailable }

        do {
            let existing = try repo.fetchAll()
            let existingValues = Set(existing.map { $0.command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })

            // Filter out commands whose value already exists locally, then assign new UUIDs
            // so they don't collide with the sender's IDs.
            let newCommands = pack.commands.compactMap { item -> CommandItem? in
                let normalised = item.command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !existingValues.contains(normalised) else { return nil }
                var copy = item
                copy.id = UUID()         // fresh ID for the recipient
                copy.pinned = false      // don't auto-pin shared commands
                return copy
            }

            guard !newCommands.isEmpty else { return 0 }

            try repo.insertBatch(newCommands)
            return newCommands.count
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.importFailed(error)
        }
    }
}
