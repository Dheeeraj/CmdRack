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
        } catch {
            throw CommandRepositoryError.databaseError(error)
        }
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
