//
//  DatabaseService.swift
//  CmdRack
//

import Foundation
import GRDB

enum DatabaseError: Error {
    case applicationSupportUnavailable
    case couldNotCreateDirectory(Error)
    case couldNotOpenDatabase(Error)
}

final class DatabaseService {
    static let shared = DatabaseService()

    private(set) var queue: DatabaseQueue?
    var isAvailable: Bool { queue != nil }

    private init() {
        do {
            guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                queue = nil
                return
            }

            let folder = appSupport.appending(path: "CmdRack", directoryHint: .isDirectory)

            if !FileManager.default.fileExists(atPath: folder.path) {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            }

            let dbPath = folder.appending(path: "cmdrack.sqlite", directoryHint: .notDirectory).path

            let dbQueue = try DatabaseQueue(path: dbPath)
            try Self.migrate(dbQueue)
            queue = dbQueue
        } catch {
            queue = nil
        }
    }

    private static func migrate(_ writer: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("create_commands") { db in
            try db.create(table: "commands") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("command", .text).notNull()
                t.column("tags", .text).notNull()
                t.column("project", .text)
                t.column("tool", .text)
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("add_commands_metadata_v1") { db in
            // Backward-compatible: only add if missing.
            let columns = try Row.fetchAll(db, sql: "PRAGMA table_info(commands)")
            let names: [String] = columns.compactMap { $0["name"] }

            guard !names.contains("metadata") else { return }

            try db.alter(table: "commands") { t in
                // Stored as JSON string (array of entries)
                t.add(column: "metadata", .text).notNull().defaults(to: "[]")
            }
        }

        try migrator.migrate(writer)
    }
}
