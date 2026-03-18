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
    /// If the database failed to initialise, this holds the error.
    private(set) var initError: Error?
    var isAvailable: Bool { queue != nil }

    private init() {
        do {
            guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                let error = DatabaseError.applicationSupportUnavailable
                self.initError = error
                queue = nil
                NSLog("[CmdRack] Database init failed: \(error)")
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
            initError = error
            NSLog("[CmdRack] Database init failed: \(error.localizedDescription)")
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

        migrator.registerMigration("create_analytics_events") { db in
            try db.create(table: "analytics_events") { t in
                t.primaryKey("id", .text)
                t.column("type", .text).notNull()
                t.column("commandId", .text)
                t.column("timestamp", .datetime).notNull()
                t.column("tags", .text)
                t.column("project", .text)
                t.column("tool", .text)
            }
            try db.create(index: "idx_analytics_events_timestamp", on: "analytics_events", columns: ["timestamp"])
            try db.create(index: "idx_analytics_events_type_timestamp", on: "analytics_events", columns: ["type", "timestamp"])
        }

        try migrator.migrate(writer)
    }

    // MARK: - Analytics helpers (for backup / restore)

    /// Fetch every analytics event in the database.
    func fetchAllAnalyticsEvents() throws -> [AnalyticsEvent] {
        guard let queue else { throw DatabaseError.applicationSupportUnavailable }
        return try queue.read { db in
            try AnalyticsEvent.fetchAll(db)
        }
    }

    /// Batch-insert analytics events, silently skipping duplicates (by primary key).
    func insertAnalyticsEvents(_ events: [AnalyticsEvent]) throws {
        guard let queue else { throw DatabaseError.applicationSupportUnavailable }
        try queue.write { db in
            for event in events {
                try event.insert(db, onConflict: .ignore)
            }
        }
    }

    /// Delete all analytics events (used by "replace" import mode).
    func deleteAllAnalyticsEvents() throws {
        guard let queue else { throw DatabaseError.applicationSupportUnavailable }
        try queue.write { db in
            try AnalyticsEvent.deleteAll(db)
        }
    }
}
