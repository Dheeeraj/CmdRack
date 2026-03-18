//
//  AppSettings.swift
//  CmdRack
//

import Foundation

/// App-wide settings persisted in UserDefaults as JSON.
/// Add new properties with a default value to extend without breaking existing installs.
struct AppSettings: Codable, Equatable {

    // MARK: - Command editor limits (stored in SQLite TEXT)

    /// SQLite's maximum TEXT length is finite (usually 1_000_000_000 bytes).
    /// We keep a hard upper bound so limits are never "unlimited".
    static let sqliteTextMax: Int = 1_000_000_000

    /// Max characters allowed in title/command/project/tool fields when creating/editing commands.
    /// Must be <= `sqliteTextMax`.
    var commandTextMax: Int = 1024  // default

    /// Max number of tags per command. Stored as JSON inside a TEXT column, so still capped by `sqliteTextMax`.
    var tagMaxCount: Int = 64  // default

    /// Max characters per tag.
    /// Must be <= `sqliteTextMax`.
    var tagTextMax: Int = 128  // default

    // MARK: - Activity / Analytics

    /// When the app was first run on this Mac; used to unlock the Activity tab after 3 days.
    var firstRunDate: Date = Date()

    /// Dev flag to force-unlock the Activity tab without waiting 3 days.
    var debugUnlockActivityTab: Bool = false

    // MARK: - Pinned

    /// How many pinned commands to show in the popup (1–10, default 5).
    var pinnedDisplayCount: Int = 5

    /// Whether pinned commands get number-key shortcuts (1–N).
    var pinnedShortcutsEnabled: Bool = true

    /// Custom shortcut keys for pinned slots 1–10 (single character each). Default: 1,2,3,4,5,6,7,8,9,0.
    var pinnedShortcutKeys: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

    // MARK: - Recent (copy-based)

    /// How many recently-copied commands to show in the popup (1–10, default 3).
    var recentDisplayCount: Int = 3

    /// Custom shortcut keys for recent slots 1–10 (single character each). Default: q,w,e,r,t,y,u,i,o,p.
    var recentShortcutKeys: [String] = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]

    /// Internal storage limit for the recent-copied list (always 10).
    static let recentStorageLimit: Int = 10

    // MARK: - Search (popup search results)

    /// Two fixed shortcuts for the first two search results in the popup.
    /// Stored as single characters with no modifiers. Default: z, x.
    var searchResultShortcutKeys: [String] = ["z", "x"]

    // MARK: - Section order

    /// Which section appears first in the popup.
    var sectionOrder: SectionOrder = .pinnedFirst

    enum SectionOrder: String, Codable, CaseIterable {
        case pinnedFirst
        case recentFirst
    }

    // MARK: - Validation

    var validated: AppSettings {
        var copy = self
        copy.commandTextMax = max(1, min(Self.sqliteTextMax, copy.commandTextMax))
        copy.tagMaxCount = max(0, min(Self.sqliteTextMax, copy.tagMaxCount))
        copy.tagTextMax = max(1, min(Self.sqliteTextMax, copy.tagTextMax))
        copy.pinnedDisplayCount = max(1, min(10, copy.pinnedDisplayCount))
        copy.recentDisplayCount = max(1, min(10, copy.recentDisplayCount))
        if copy.pinnedShortcutKeys.count != 10 {
            copy.pinnedShortcutKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        }
        if copy.recentShortcutKeys.count != 10 {
            copy.recentShortcutKeys = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
        }
        if copy.searchResultShortcutKeys.count != 2 {
            copy.searchResultShortcutKeys = ["z", "x"]
        }
        if copy.searchResultShortcutKeys.count == 2 {
            let cleaned = copy.searchResultShortcutKeys.map { raw -> String in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard let first = trimmed.first else { return "" }
                return String(first)
            }
            if cleaned.contains(where: { $0.isEmpty }) {
                copy.searchResultShortcutKeys = ["z", "x"]
            } else {
                copy.searchResultShortcutKeys = cleaned
            }
        }
        return copy
    }
}

// MARK: - UserDefaults persistence

extension AppSettings {
    private static let storageKey = "CmdRack.AppSettings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return decoded.validated
    }

    func save() {
        let validated = self.validated
        guard let data = try? JSONEncoder().encode(validated) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        NotificationCenter.default.post(name: .cmdRackSettingsDidChange, object: nil)
    }
}
