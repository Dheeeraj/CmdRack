//
//  CmdRackSharePack.swift
//  CmdRack
//

import Foundation

/// A lightweight, shareable command pack — commands only, no analytics, no settings.
/// Recipients can import these without inheriting the sender's usage data.
struct CmdRackSharePack: Codable {

    // MARK: - Schema version

    static let currentVersion: Int = 1

    /// Schema version used when this pack was created.
    let version: Int

    /// ISO-8601 timestamp of when the pack was exported.
    let exportedAt: Date

    /// Human-readable device name of the exporter.
    let deviceName: String

    /// How the commands were filtered (for display in the import sheet).
    let filterDescription: String

    // MARK: - Payload (commands only — no analytics, settings, pinned/recent order)

    let commands: [CommandItem]

    // MARK: - Factory

    static func pack(
        commands: [CommandItem],
        filterDescription: String
    ) -> CmdRackSharePack {
        CmdRackSharePack(
            version: currentVersion,
            exportedAt: Date(),
            deviceName: Host.current().localizedName ?? "Unknown Mac",
            filterDescription: filterDescription,
            commands: commands
        )
    }
}
