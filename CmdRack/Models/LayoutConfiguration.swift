//
//  LayoutConfiguration.swift
//  CmdRack
//

import Foundation

// MARK: - Section filter (tag / project / tool)

enum LayoutSectionFilter: Codable, Equatable {
    case tag(String)
    case project(String)
    case tool(String)

    /// Human-readable label for the filter type.
    var typeLabel: String {
        switch self {
        case .tag:     return "Tag"
        case .project: return "Project"
        case .tool:    return "Tool"
        }
    }

    /// The filter value (tag name, project name, or tool name).
    var value: String {
        switch self {
        case .tag(let v), .project(let v), .tool(let v): return v
        }
    }
}

// MARK: - Layout section

struct LayoutSection: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var title: String                    // section header shown in the popup
    var filter: LayoutSectionFilter
    var commandOrder: [UUID] = []        // user-defined drag-to-reorder; missing IDs appended alphabetically
}

// MARK: - Layout configuration

struct LayoutConfiguration: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String                     // e.g. "DevOps", "Frontend"
    var sections: [LayoutSection]
    var shortcutKeys: [String]           // up to 30, assigned sequentially across all sections
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Default shortcut keys for a new layout (30 keys: 1-0, q-p, a-;).
    static let defaultShortcutKeys: [String] = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "q", "w", "e", "r", "t", "y", "u", "i", "o", "p",
        "a", "s", "d", "f", "g", "h", "j", "k", "l", ";"
    ]

    /// Creates a new layout with default shortcut keys.
    static func create(name: String, sections: [LayoutSection] = []) -> LayoutConfiguration {
        LayoutConfiguration(
            name: name,
            sections: sections,
            shortcutKeys: defaultShortcutKeys
        )
    }
}
