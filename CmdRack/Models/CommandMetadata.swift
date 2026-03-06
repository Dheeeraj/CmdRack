//
//  CommandMetadata.swift
//  CmdRack
//

import Foundation

enum CommandMetadataType: String, Codable {
    case create
    case update
}

/// Stored inside `commands.metadata` as a JSON array.
struct CommandMetadataEntry: Codable, Equatable {
    /// Metadata schema version (so future changes can be backward compatible).
    var vm: Int
    /// App version (int) at time of the event.
    var v: Int
    /// Event type.
    var type: CommandMetadataType
    /// Human-readable device name.
    var device: String
    /// Stable, app-generated device identifier.
    var deviceId: String
    /// ISO8601 UTC timestamp (e.g. 2026-02-09T12:34:56Z).
    var createdUTC: String

    static func make(type: CommandMetadataType, date: Date = Date()) -> CommandMetadataEntry {
        CommandMetadataEntry(
            vm: 1,
            v: AppBuildInfo.appVersionInt,
            type: type,
            device: DeviceIdentity.deviceName,
            deviceId: DeviceIdentity.deviceId,
            createdUTC: ISO8601DateFormatter.cmdRackUTC.string(from: date)
        )
    }
}

enum AppBuildInfo {
    static var appVersionInt: Int {
        // Prefer build number if it's an int.
        if let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           let i = Int(build) {
            return i
        }
        // Fall back to major from short version (e.g. "1.2.3" -> 1).
        if let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            let major = short.split(separator: ".").first.map(String.init) ?? "0"
            return Int(major) ?? 0
        }
        return 0
    }
}

enum DeviceIdentity {
    private static let key = "CmdRackDeviceID"

    static var deviceName: String {
        Host.current().localizedName ?? "Mac"
    }

    static var deviceId: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: key)
        return newId
    }
}

private extension ISO8601DateFormatter {
    static let cmdRackUTC: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}

