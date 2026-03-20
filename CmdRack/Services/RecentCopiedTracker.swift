//
//  RecentCopiedTracker.swift
//  CmdRack
//

import Foundation

/// Tracks which commands were recently *copied* (not recently added).
/// Stores up to `AppSettings.recentStorageLimit` (10) IDs ordered by most-recent-copy first.
/// On copy: push to top, deduplicate, trim to limit.
final class RecentCopiedTracker {
    static let shared = RecentCopiedTracker()

    private static let storageKey = "CmdRack.RecentCopiedIDs"

    private init() {}

    /// Ordered list of command IDs, most-recently-copied first.
    var ids: [UUID] {
        get {
            guard let raw = UserDefaults.standard.stringArray(forKey: Self.storageKey) else { return [] }
            return raw.compactMap { UUID(uuidString: $0) }
        }
        set {
            let trimmed = Array(newValue.prefix(AppSettings.recentStorageLimit))
            UserDefaults.standard.set(trimmed.map(\.uuidString), forKey: Self.storageKey)
        }
    }

    /// Record a copy event — pushes to top, deduplicates, trims.
    func recordCopy(id: UUID) {
        var current = ids
        current.removeAll { $0 == id }
        current.insert(id, at: 0)
        ids = current
        NotificationCenter.default.post(name: .cmdRackRecentCopiedDidChange, object: nil)
    }

    /// Remove a specific ID (e.g. when a command is deleted).
    func remove(id: UUID) {
        var current = ids
        current.removeAll { $0 == id }
        ids = current
    }

    func clear() {
        ids = []
        NotificationCenter.default.post(name: .cmdRackRecentCopiedDidChange, object: nil)
    }
}
