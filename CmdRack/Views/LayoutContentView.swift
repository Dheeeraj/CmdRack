//
//  LayoutContentView.swift
//  CmdRack
//
//  Renders a custom layout's sections in the popup menu.
//  Filters commands in memory from the preloaded list — no DB calls.
//

import SwiftUI

struct LayoutContentView: View {
    let layout: LayoutConfiguration
    let allCommands: [CommandItem]
    var onCopy: (CommandItem) -> Void

    // MARK: - Resolved sections

    /// Each resolved section pairs a layout section with its matching, ordered commands.
    private var resolvedSections: [(section: LayoutSection, commands: [CommandItem])] {
        layout.sections.compactMap { section in
            let filtered: [CommandItem]
            switch section.filter {
            case .tag(let tag):
                filtered = allCommands.filter { $0.tags.contains(tag) }
            case .project(let project):
                filtered = allCommands.filter { ($0.project ?? "") == project }
            case .tool(let tool):
                filtered = allCommands.filter { ($0.tool ?? "") == tool }
            }
            guard !filtered.isEmpty else { return nil }
            let ordered = applyOrder(filtered, order: section.commandOrder)
            return (section, ordered)
        }
    }

    /// Total commands across all sections (used for scroll threshold).
    private var totalCommandCount: Int {
        resolvedSections.reduce(0) { $0 + $1.commands.count }
    }

    /// Cumulative command offset for each resolved section index, used to map
    /// section-local indices to the layout-wide shortcut key array.
    private var sectionOffsets: [Int] {
        var offsets: [Int] = []
        var running = 0
        for resolved in resolvedSections {
            offsets.append(running)
            running += resolved.commands.count
        }
        return offsets
    }

    var body: some View {
        let sections = resolvedSections
        let offsets = sectionOffsets

        if sections.isEmpty {
            Text("No commands match this layout")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        } else {
            let content = VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(sections.enumerated()), id: \.element.section.id) { sectionIndex, resolved in
                    let offset = offsets[sectionIndex]
                    CommandListSectionView(
                        title: resolved.section.title,
                        items: resolved.commands,
                        shortcutKeyForIndex: { index in
                            let globalIndex = offset + index
                            guard globalIndex < layout.shortcutKeys.count else { return nil }
                            let key = layout.shortcutKeys[globalIndex]
                            return key.isEmpty ? nil : key
                        },
                        onSelect: onCopy
                    )
                }
            }

            if totalCommandCount > 20 {
                ScrollView {
                    content
                }
                .frame(maxHeight: 400)
            } else {
                content
            }
        }
    }

    // MARK: - Ordering

    /// Applies user-defined command order. Commands in `order` come first (in that sequence),
    /// then any remaining commands are appended alphabetically by title.
    private func applyOrder(_ commands: [CommandItem], order: [UUID]) -> [CommandItem] {
        guard !order.isEmpty else {
            return commands.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        let byID = Dictionary(uniqueKeysWithValues: commands.map { ($0.id, $0) })
        var result: [CommandItem] = []
        var seen = Set<UUID>()

        // Ordered commands first
        for id in order {
            if let cmd = byID[id], !seen.contains(id) {
                result.append(cmd)
                seen.insert(id)
            }
        }

        // Remaining commands alphabetically
        let remaining = commands
            .filter { !seen.contains($0.id) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        result.append(contentsOf: remaining)

        return result
    }
}
