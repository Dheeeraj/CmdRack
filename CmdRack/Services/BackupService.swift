//
//  BackupService.swift
//  CmdRack
//

import Foundation

// MARK: - Import mode

enum BackupImportMode {
    /// Keep existing data; only add records whose IDs don't already exist.
    case merge
    /// Delete all existing data first, then import everything from the backup.
    case replace
}

// MARK: - Import result

struct BackupImportResult {
    let commandsImported: Int
    let analyticsEventsImported: Int
    let settingsRestored: Bool
    let pinnedOrderRestored: Bool
    let recentCopiedRestored: Bool
}

// MARK: - Errors

enum BackupError: LocalizedError {
    case encodingFailed
    case decodingFailed(Error)
    case unsupportedVersion(Int)
    case databaseUnavailable
    case exportFailed(Error)
    case importFailed(Error)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode backup data."
        case .decodingFailed(let error):
            return "Failed to read backup file: \(error.localizedDescription)"
        case .unsupportedVersion(let v):
            return "Unsupported backup version (\(v)). Please update CmdRack."
        case .databaseUnavailable:
            return "Database is not available."
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        case .importFailed(let error):
            return "Import failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Service

enum BackupService {

    // MARK: - JSON coding helpers

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Export

    /// Build a full backup of commands, analytics, settings, pinned order, and recent-copied list.
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

            guard let data = try? makeEncoder().encode(backup) else {
                throw BackupError.encodingFailed
            }
            return data
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.exportFailed(error)
        }
    }

    // MARK: - Import

    /// Restore data from a previously exported backup.
    @discardableResult
    static func importBackup(from data: Data, mode: BackupImportMode) throws -> BackupImportResult {
        let backup: CmdRackBackup
        do {
            backup = try makeDecoder().decode(CmdRackBackup.self, from: data)
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
            try db.insertAnalyticsEvents(backup.analyticsEvents)

            // --- Settings ---
            backup.settings.save()

            // --- Pinned order ---
            let pinnedUUIDs = backup.pinnedOrderIDs.compactMap { UUID(uuidString: $0) }
            PinnedOrderStore.shared.ids = pinnedUUIDs
            NotificationCenter.default.post(name: .cmdRackPinnedOrderDidChange, object: nil)

            // --- Recent copied ---
            let recentUUIDs = backup.recentCopiedIDs.compactMap { UUID(uuidString: $0) }
            RecentCopiedTracker.shared.ids = recentUUIDs
            NotificationCenter.default.post(name: .cmdRackRecentCopiedDidChange, object: nil)

            return BackupImportResult(
                commandsImported: commandsImported,
                analyticsEventsImported: backup.analyticsEvents.count,
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
}
