//
//  AnalyticsService.swift
//  CmdRack
//

import Foundation
import GRDB

struct DailyCount {
    let date: Date
    let count: Int
}

struct CommandUsageSummary {
    let command: CommandItem
    let count: Int
}

struct StringUsageSummary {
    let key: String
    let count: Int
}

final class AnalyticsService {
    static let shared = AnalyticsService()

    private let database: DatabaseService
    private let repository: CommandRepository

    init(database: DatabaseService = .shared, repository: CommandRepository = CommandRepository()) {
        self.database = database
        self.repository = repository
    }

    // MARK: - Tracking

    /// Records a popover open. Pass how it was opened (shortcut vs menu bar click).
    func trackPopoverOpen(trigger: PopoverOpenTrigger) {
        let type: AnalyticsEventType = trigger == .shortcut ? .popoverOpenShortcut : .popoverOpenClick
        insertEvent(
            AnalyticsEvent(
                type: type,
                commandId: nil,
                tagsJSON: nil,
                project: nil,
                tool: nil
            )
        )
    }

    func trackCommandCopied(_ command: CommandItem) {
        let tagsJSON: String?
        if command.tags.isEmpty {
            tagsJSON = nil
        } else if let data = try? JSONEncoder().encode(command.tags),
                  let json = String(data: data, encoding: .utf8) {
            tagsJSON = json
        } else {
            tagsJSON = nil
        }

        insertEvent(
            AnalyticsEvent(
                type: .commandCopied,
                commandId: command.id,
                tagsJSON: tagsJSON,
                project: command.project,
                tool: command.tool
            )
        )
    }

    private func insertEvent(_ event: AnalyticsEvent) {
        guard let queue = database.queue else { return }
        do {
            try queue.write { db in
                try event.insert(db)
            }
        } catch {
            // Analytics is best-effort; ignore failures.
            print("[Analytics] Failed to insert event: \(error)")
        }
    }

    // MARK: - Aggregations

    /// All popover open types (legacy popover_open, popover_open_shortcut, popover_open_click).
    private static let popoverOpenTypes: [String] = [
        AnalyticsEventType.popoverOpen.rawValue,
        AnalyticsEventType.popoverOpenShortcut.rawValue,
        AnalyticsEventType.popoverOpenClick.rawValue
    ]

    func totalPopoverOpens() -> Int {
        guard let queue = database.queue else { return 0 }
        do {
            return try queue.read { db in
                let placeholders = Self.popoverOpenTypes.map { _ in "?" }.joined(separator: ", ")
                return try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM analytics_events WHERE type IN (\(placeholders))",
                    arguments: StatementArguments(Self.popoverOpenTypes)
                ) ?? 0
            }
        } catch {
            return 0
        }
    }

    func totalPopoverOpensViaShortcut() -> Int {
        countEvents(type: AnalyticsEventType.popoverOpenShortcut.rawValue)
    }

    func totalPopoverOpensViaClick() -> Int {
        countEvents(type: AnalyticsEventType.popoverOpenClick.rawValue)
    }

    private func countEvents(type: String) -> Int {
        guard let queue = database.queue else { return 0 }
        do {
            return try queue.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM analytics_events WHERE type = ?", arguments: [type]) ?? 0
            }
        } catch {
            return 0
        }
    }

    func dailyPopoverOpens(lastDays: Int) -> [DailyCount] {
        guard lastDays > 0, let queue = database.queue else { return [] }
        do {
            return try queue.read { db in
                let placeholders = Self.popoverOpenTypes.map { _ in "?" }.joined(separator: ", ")
                let args = Self.popoverOpenTypes + ["-\(lastDays - 1) days"]
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT DATE(timestamp) AS day, COUNT(*) AS c
                    FROM analytics_events
                    WHERE type IN (\(placeholders))
                      AND timestamp >= DATE('now', ?)
                    GROUP BY day
                    ORDER BY day ASC
                    """,
                    arguments: StatementArguments(args)
                )
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]
                return rows.compactMap { row in
                    if let dayString: String = row["day"],
                       let date = formatter.date(from: dayString) {
                        let count: Int = row["c"]
                        return DailyCount(date: date, count: count)
                    }
                    return nil
                }
            }
        } catch {
            return []
        }
    }

    func mostCopiedCommands(lastDays: Int?, limit: Int) -> [CommandUsageSummary] {
        guard let queue = database.queue, limit > 0 else { return [] }
        do {
            return try queue.read { db in
                var sql = """
                SELECT commandId, COUNT(*) AS c
                FROM analytics_events
                WHERE type = ?
                """
                var args: [DatabaseValueConvertible] = [AnalyticsEventType.commandCopied.rawValue]

                if let days = lastDays, days > 0 {
                    sql += " AND timestamp >= DATE('now', ?)"
                    args.append("-\(days - 1) days")
                }

                sql += " AND commandId IS NOT NULL GROUP BY commandId ORDER BY c DESC LIMIT ?"
                args.append(limit)

                let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
                let allCommands = try CommandItem.fetchAll(db)
                let byID = Dictionary(uniqueKeysWithValues: allCommands.map { ($0.id, $0) })

                return rows.compactMap { row in
                    guard let idString: String = row["commandId"],
                          let uuid = UUID(uuidString: idString),
                          let cmd = byID[uuid] else { return nil }
                    let count: Int = row["c"]
                    return CommandUsageSummary(command: cmd, count: count)
                }
            }
        } catch {
            return []
        }
    }

    func topTags(lastDays: Int?, limit: Int) -> [StringUsageSummary] {
        topStringField(column: "tags", lastDays: lastDays, limit: limit) { tagsJSON in
            // tagsJSON is a JSON array of strings; flatten all tags.
            guard let data = tagsJSON.data(using: .utf8),
                  let tags = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return tags
        }
    }

    func topTools(lastDays: Int?, limit: Int) -> [StringUsageSummary] {
        topStringField(column: "tool", lastDays: lastDays, limit: limit) { [$0] }
    }

    func topProjects(lastDays: Int?, limit: Int) -> [StringUsageSummary] {
        topStringField(column: "project", lastDays: lastDays, limit: limit) { [$0] }
    }

    private func topStringField(
        column: String,
        lastDays: Int?,
        limit: Int,
        explode: (String) -> [String]
    ) -> [StringUsageSummary] {
        guard let queue = database.queue, limit > 0 else { return [] }
        do {
            return try queue.read { db in
                var sql = """
                SELECT \(column) AS v, COUNT(*) AS c
                FROM analytics_events
                WHERE type = ?
                  AND \(column) IS NOT NULL
                """
                var args: [DatabaseValueConvertible] = [AnalyticsEventType.commandCopied.rawValue]

                if let days = lastDays, days > 0 {
                    sql += " AND timestamp >= DATE('now', ?)"
                    args.append("-\(days - 1) days")
                }

                sql += " GROUP BY v ORDER BY c DESC"

                let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))

                // For tags we may need to explode JSON arrays; for others, explode is identity.
                var counts: [String: Int] = [:]
                for row in rows {
                    guard let raw: String = row["v"] else { continue }
                    let exploded = explode(raw)
                    let baseCount: Int = row["c"]
                    for key in exploded {
                        counts[key, default: 0] += baseCount
                    }
                }

                return counts
                    .sorted { $0.value > $1.value }
                    .prefix(limit)
                    .map { StringUsageSummary(key: $0.key, count: $0.value) }
            }
        } catch {
            return []
        }
    }
}

