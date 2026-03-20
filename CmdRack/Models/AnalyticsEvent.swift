//
//  AnalyticsEvent.swift
//  CmdRack
//

import Foundation
import GRDB

enum AnalyticsEventType: String, Codable {
    case popoverOpen = "popover_open"
    case popoverOpenShortcut = "popover_open_shortcut"
    case popoverOpenClick = "popover_open_click"
    case commandCopied = "command_copied"
}

/// How the popover was opened; used when recording popover_open_shortcut vs popover_open_click.
enum PopoverOpenTrigger {
    case shortcut
    case click
}

struct AnalyticsEvent: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable {
    static let databaseTableName = "analytics_events"

    var id: UUID
    var type: AnalyticsEventType
    var commandId: UUID?
    var timestamp: Date
    var tagsJSON: String?
    var project: String?
    var tool: String?

    init(
        id: UUID = UUID(),
        type: AnalyticsEventType,
        commandId: UUID?,
        timestamp: Date = Date(),
        tagsJSON: String?,
        project: String?,
        tool: String?
    ) {
        self.id = id
        self.type = type
        self.commandId = commandId
        self.timestamp = timestamp
        self.tagsJSON = tagsJSON
        self.project = project
        self.tool = tool
    }

    init(row: Row) throws {
        let rawID: String = row["id"]
        if let parsed = UUID(uuidString: rawID) {
            id = parsed
        } else {
            id = UUID()
            NSLog("[CmdRack] AnalyticsEvent has malformed UUID: \(rawID) — assigned new id \(id)")
        }
        type = AnalyticsEventType(rawValue: row["type"]) ?? .popoverOpen
        if let cmd: String? = row["commandId"], let raw = cmd, let uuid = UUID(uuidString: raw) {
            commandId = uuid
        } else {
            commandId = nil
        }
        timestamp = row["timestamp"]
        tagsJSON = row["tags"]
        project = row["project"]
        tool = row["tool"]
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id.uuidString
        container["type"] = type.rawValue
        container["commandId"] = commandId?.uuidString
        container["timestamp"] = timestamp
        container["tags"] = tagsJSON
        container["project"] = project
        container["tool"] = tool
    }
}

