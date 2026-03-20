//
//  AppSettings.swift
//  CmdRack
//

import Foundation
import AppKit
import SwiftUI

// MARK: - Preferred terminal

enum PreferredTerminal: String, Codable, CaseIterable, Equatable {
    case terminal   = "Terminal"
    case iterm2     = "iTerm2"
    case warp       = "Warp"
    case kitty      = "Kitty"
    case ghostty    = "Ghostty"
    case alacritty  = "Alacritty"

    /// The macOS bundle identifier.
    var bundleIdentifier: String {
        switch self {
        case .terminal:  return "com.apple.Terminal"
        case .iterm2:    return "com.googlecode.iterm2"
        case .warp:      return "dev.warp.Warp-Stable"
        case .kitty:     return "net.kovidgoyal.kitty"
        case .ghostty:   return "com.mitchellh.ghostty"
        case .alacritty: return "org.alacritty"
        }
    }

    /// Display name shown in settings.
    var displayName: String { rawValue }

    /// Whether this terminal app is installed on the current Mac.
    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    /// Returns only the terminals that are actually installed.
    static var installed: [PreferredTerminal] {
        allCases.filter { $0.isInstalled }
    }
}

// MARK: - Shortcut action & modifier

/// What pressing a bare shortcut key does.
enum ShortcutAction: String, Codable, CaseIterable, Equatable {
    case copy    = "Copy"
    case run     = "Run in Terminal"

    var displayName: String { rawValue }
}

/// Which modifier key triggers the alternate shortcut action.
enum TerminalModifierKey: String, Codable, CaseIterable, Equatable {
    case control = "Control"
    case shift   = "Shift"
    case command = "Command"
    case option  = "Option"

    var displayName: String { rawValue }

    /// The symbol shown in UI.
    var symbol: String {
        switch self {
        case .control: return "⌃"
        case .shift:   return "⇧"
        case .command: return "⌘"
        case .option:  return "⌥"
        }
    }

    /// Maps to SwiftUI's EventModifiers.
    var eventModifier: SwiftUI.EventModifiers {
        switch self {
        case .control: return .control
        case .shift:   return .shift
        case .command: return .command
        case .option:  return .option
        }
    }
}

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

    /// Keys reserved by the app for fixed actions (Add Command, Manage, Quit, Tab).
    static let reservedKeys: Set<String> = ["=", "m", "⌫"]

    // MARK: - Layouts

    /// Custom layouts that replace the default pinned+recent view in the popup.
    var layouts: [LayoutConfiguration] = []

    /// ID of the currently active layout. `nil` = default (pinned+recent).
    var activeLayoutId: UUID? = nil

    // MARK: - Terminal

    /// The terminal app to use when running commands with modifier+shortcut key.
    var preferredTerminal: PreferredTerminal = .terminal

    /// What pressing a bare shortcut key does: copy command or run in terminal.
    var defaultShortcutAction: ShortcutAction = .copy

    /// Which modifier key triggers the alternate action.
    var terminalModifierKey: TerminalModifierKey = .control

    /// Whether the terminal tip has been dismissed.
    var terminalTipDismissed: Bool = false

    // MARK: - Shortcut groups

    enum ShortcutGroup { case pinned, recent, search }

    /// Returns a conflict description if `key` is already assigned in another group or is reserved.
    /// Pass the group currently being edited so keys within that group are skipped.
    func conflictDescription(for key: String, excluding group: ShortcutGroup) -> String? {
        let k = key.lowercased()

        if Self.reservedKeys.contains(k) {
            return "\"\(key)\" is reserved by the app."
        }

        if group != .pinned, let idx = pinnedShortcutKeys.firstIndex(where: { $0.lowercased() == k }) {
            return "\"\(key)\" is already used by Pinned shortcuts (slot \(idx + 1))."
        }
        if group != .recent, let idx = recentShortcutKeys.firstIndex(where: { $0.lowercased() == k }) {
            return "\"\(key)\" is already used by Recent shortcuts (slot \(idx + 1))."
        }
        if group != .search, let idx = searchResultShortcutKeys.firstIndex(where: { $0.lowercased() == k }) {
            return "\"\(key)\" is already used by Search result shortcuts (slot \(idx + 1))."
        }

        return nil
    }

    /// Returns a conflict description when editing shortcut keys inside a layout.
    /// Layout keys only conflict with reserved keys, search shortcuts, and same-layout duplicates
    /// (layouts replace pinned+recent, so those groups don't conflict).
    func layoutConflictDescription(for key: String, in layout: LayoutConfiguration, excludingIndex: Int) -> String? {
        let k = key.lowercased()

        if Self.reservedKeys.contains(k) {
            return "\"\(key)\" is reserved by the app."
        }
        if let idx = searchResultShortcutKeys.firstIndex(where: { $0.lowercased() == k }) {
            return "\"\(key)\" is already used by Search result shortcuts (slot \(idx + 1))."
        }
        for (idx, existing) in layout.shortcutKeys.enumerated() where idx != excludingIndex {
            if existing.lowercased() == k {
                return "\"\(key)\" is already used in slot \(idx + 1) of this layout."
            }
        }
        return nil
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

        // Deduplicate: if any shortcut key appears in more than one group or
        // clashes with a reserved key, reset the offending group to defaults.
        let pinnedSet  = Set(copy.pinnedShortcutKeys.map { $0.lowercased() })
        let recentSet  = Set(copy.recentShortcutKeys.map { $0.lowercased() })
        let searchSet  = Set(copy.searchResultShortcutKeys.map { $0.lowercased() })

        if !pinnedSet.isDisjoint(with: recentSet) || !pinnedSet.isDisjoint(with: searchSet)
            || !pinnedSet.isDisjoint(with: Self.reservedKeys) {
            copy.pinnedShortcutKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        }
        if !recentSet.isDisjoint(with: searchSet) || !recentSet.isDisjoint(with: Self.reservedKeys) {
            copy.recentShortcutKeys = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
        }
        if !searchSet.isDisjoint(with: Self.reservedKeys) {
            copy.searchResultShortcutKeys = ["z", "x"]
        }

        // Terminal: fall back to Terminal.app if the saved choice is not installed
        if !copy.preferredTerminal.isInstalled {
            copy.preferredTerminal = .terminal
        }

        // Layouts: prune stale activeLayoutId, cap shortcut keys at 30
        if let activeId = copy.activeLayoutId,
           !copy.layouts.contains(where: { $0.id == activeId }) {
            copy.activeLayoutId = nil
        }
        for i in copy.layouts.indices {
            if copy.layouts[i].shortcutKeys.count > 30 {
                copy.layouts[i].shortcutKeys = Array(copy.layouts[i].shortcutKeys.prefix(30))
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
