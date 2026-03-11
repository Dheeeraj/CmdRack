//
//  AppSettings.swift
//  CmdRack
//

import Foundation

/// App-wide settings persisted in UserDefaults as JSON.
/// Add new properties with a default value to extend without breaking existing installs.
struct AppSettings: Codable, Equatable {

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
        copy.pinnedDisplayCount = max(1, min(10, copy.pinnedDisplayCount))
        copy.recentDisplayCount = max(1, min(10, copy.recentDisplayCount))
        if copy.pinnedShortcutKeys.count != 10 {
            copy.pinnedShortcutKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        }
        if copy.recentShortcutKeys.count != 10 {
            copy.recentShortcutKeys = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
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
