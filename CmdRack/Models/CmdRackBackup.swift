//
//  CmdRackBackup.swift
//  CmdRack
//

import Foundation

/// Versioned envelope for exporting / importing all CmdRack data.
/// Bump `currentVersion` whenever the schema changes.
struct CmdRackBackup: Codable {

    // MARK: - Schema version

    static let currentVersion: Int = 1

    /// Schema version used when this backup was created.
    let version: Int

    /// ISO-8601 timestamp of when the backup was exported.
    let exportedAt: Date

    /// Human-readable device name (e.g. "MacBook Pro").
    let deviceName: String

    // MARK: - Payload

    let commands: [CommandItem]
    let analyticsEvents: [AnalyticsEvent]
    let settings: AppSettings
    let pinnedOrderIDs: [String]
    let recentCopiedIDs: [String]

    // MARK: - Factory

    /// Build a backup snapshot from the current state of the app.
    static func snapshot(
        commands: [CommandItem],
        analyticsEvents: [AnalyticsEvent],
        settings: AppSettings,
        pinnedOrderIDs: [UUID],
        recentCopiedIDs: [UUID]
    ) -> CmdRackBackup {
        CmdRackBackup(
            version: currentVersion,
            exportedAt: Date(),
            deviceName: Host.current().localizedName ?? "Unknown Mac",
            commands: commands,
            analyticsEvents: analyticsEvents,
            settings: settings,
            pinnedOrderIDs: pinnedOrderIDs.map(\.uuidString),
            recentCopiedIDs: recentCopiedIDs.map(\.uuidString)
        )
    }
}
