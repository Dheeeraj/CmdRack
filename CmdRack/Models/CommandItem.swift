//
//  CommandItem.swift
//  CmdRack
//

import Foundation
import GRDB

struct CommandItem: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable {
    static let databaseTableName = "commands"

    var id: UUID
    var title: String
    var command: String
    var tags: [String]
    var metadata: [CommandMetadataEntry]
    var project: String?
    var tool: String?
    var pinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        title: String,
        command: String,
        tags: [String] = [],
        metadata: [CommandMetadataEntry] = [],
        project: String? = nil,
        tool: String? = nil,
        pinned: Bool = false,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.command = command
        self.tags = tags
        self.metadata = metadata
        self.project = project
        self.tool = tool
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - FetchableRecord (decode from row)

    init(row: Row) throws {
        id = UUID(uuidString: row["id"]) ?? UUID()
        title = row["title"]
        command = row["command"]
        project = row["project"]
        tool = row["tool"]
        pinned = row["pinned"]
        createdAt = row["createdAt"]
        updatedAt = row["updatedAt"]

        let tagsString: String? = row["tags"]
        if let raw = tagsString, !raw.isEmpty {
            let data = Data(raw.utf8)
            tags = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        } else {
            tags = []
        }

        let metadataString: String? = row["metadata"]
        if let raw = metadataString, !raw.isEmpty {
            let data = Data(raw.utf8)
            metadata = (try? JSONDecoder().decode([CommandMetadataEntry].self, from: data)) ?? []
        } else {
            metadata = []
        }
    }

    // MARK: - PersistableRecord (encode to container)

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id.uuidString
        container["title"] = title
        container["command"] = command
        container["project"] = project
        container["tool"] = tool
        container["pinned"] = pinned
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt

        if tags.isEmpty {
            container["tags"] = "[]"
        } else if let data = try? JSONEncoder().encode(tags),
                  let json = String(data: data, encoding: .utf8) {
            container["tags"] = json
        } else {
            container["tags"] = "[]"
        }

        if metadata.isEmpty {
            container["metadata"] = "[]"
        } else if let data = try? JSONEncoder().encode(metadata),
                  let json = String(data: data, encoding: .utf8) {
            container["metadata"] = json
        } else {
            container["metadata"] = "[]"
        }
    }
}
