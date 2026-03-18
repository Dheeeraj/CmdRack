//
//  CommandRepository.swift
//  CmdRack
//

import Foundation
import GRDB

enum CommandRepositoryError: Error {
    case databaseUnavailable
    case databaseError(Error)
}

final class CommandRepository {
    private let database: DatabaseService

    init(database: DatabaseService = .shared) {
        self.database = database
    }

    func fetchAll() throws -> [CommandItem] {
        guard let queue = database.queue else {
            throw CommandRepositoryError.databaseUnavailable
        }
        return try queue.read { db in
            try CommandItem.fetchAll(db)
        }
    }

    func insert(_ command: CommandItem) throws {
        guard let queue = database.queue else {
            throw CommandRepositoryError.databaseUnavailable
        }
        do {
            try queue.write { db in
                try command.insert(db)
            }
            NotificationCenter.default.post(name: .cmdRackCommandsDidChange, object: nil)
        } catch {
            throw CommandRepositoryError.databaseError(error)
        }
    }

    func update(_ command: CommandItem) throws {
        guard let queue = database.queue else {
            throw CommandRepositoryError.databaseUnavailable
        }
        do {
            try queue.write { db in
                try command.update(db)
            }
            NotificationCenter.default.post(name: .cmdRackCommandsDidChange, object: nil)
        } catch {
            throw CommandRepositoryError.databaseError(error)
        }
    }

    func delete(id: UUID) throws {
        guard let queue = database.queue else {
            throw CommandRepositoryError.databaseUnavailable
        }
        do {
            try queue.write { db in
                try CommandItem.filter(Column("id") == id.uuidString).deleteAll(db)
            }
            NotificationCenter.default.post(name: .cmdRackCommandsDidChange, object: nil)
        } catch {
            throw CommandRepositoryError.databaseError(error)
        }
    }

    func deleteAll() throws {
        guard let queue = database.queue else {
            throw CommandRepositoryError.databaseUnavailable
        }
        try queue.write { db in
            try CommandItem.deleteAll(db)
        }
        NotificationCenter.default.post(name: .cmdRackCommandsDidChange, object: nil)
    }

    func fetchByTool(_ tool: String) throws -> [CommandItem] {
        guard let queue = database.queue else {
            throw CommandRepositoryError.databaseUnavailable
        }
        return try queue.read { db in
            try CommandItem
                .filter(Column("tool") == tool)
                .fetchAll(db)
        }
    }

    /// Batch-insert commands, silently skipping duplicates (by primary key).
    /// Posts a single change notification after all inserts.
    func insertBatch(_ commands: [CommandItem]) throws {
        guard let queue = database.queue else {
            throw CommandRepositoryError.databaseUnavailable
        }
        do {
            try queue.write { db in
                for command in commands {
                    try command.insert(db, onConflict: .ignore)
                }
            }
            NotificationCenter.default.post(name: .cmdRackCommandsDidChange, object: nil)
        } catch {
            throw CommandRepositoryError.databaseError(error)
        }
    }

    func fetchByProject(_ project: String) throws -> [CommandItem] {
        guard let queue = database.queue else {
            throw CommandRepositoryError.databaseUnavailable
        }
        return try queue.read { db in
            try CommandItem
                .filter(Column("project") == project)
                .fetchAll(db)
        }
    }
}
