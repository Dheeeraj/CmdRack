//
//  ShareExportSheet.swift
//  CmdRack
//

import SwiftUI

// MARK: - Selectable item model

struct ShareSelectableItem: Identifiable, Hashable {
    enum Group: String { case tag = "Tags", project = "Projects", tool = "Tools" }
    let group: Group
    let value: String
    let commandCount: Int
    var id: String { "\(group.rawValue):\(value)" }
}

// MARK: - Share Export Sheet

struct ShareExportSheet: View {
    let onExport: (Data, String) -> Void
    let onCancel: () -> Void

    /// Pre-fill with specific commands (bypasses checklist).
    var prefilledCommands: [CommandItem]?
    var prefilledLabel: String?

    @State private var allCommands: [CommandItem] = []
    @State private var selected: Set<String> = []          // item ids
    @State private var selectAll = false                    // "All" folder — includes untagged commands
    @State private var isExporting = false
    @State private var errorMessage: String?

    private var isPrefilled: Bool { prefilledCommands != nil }

    // Build grouped items from all commands
    private var groupedItems: [(ShareSelectableItem.Group, [ShareSelectableItem])] {
        var result: [(ShareSelectableItem.Group, [ShareSelectableItem])] = []

        // Tags
        let tags = Array(Set(allCommands.flatMap(\.tags))).sorted()
        if !tags.isEmpty {
            let items = tags.map { t in
                ShareSelectableItem(group: .tag, value: t, commandCount: allCommands.filter { $0.tags.contains(t) }.count)
            }
            result.append((.tag, items))
        }

        // Projects
        let projects = Array(Set(allCommands.compactMap { $0.project?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })).sorted()
        if !projects.isEmpty {
            let items = projects.map { p in
                ShareSelectableItem(group: .project, value: p, commandCount: allCommands.filter { ($0.project ?? "") == p }.count)
            }
            result.append((.project, items))
        }

        // Tools
        let tools = Array(Set(allCommands.compactMap { $0.tool?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })).sorted()
        if !tools.isEmpty {
            let items = tools.map { t in
                ShareSelectableItem(group: .tool, value: t, commandCount: allCommands.filter { ($0.tool ?? "") == t }.count)
            }
            result.append((.tool, items))
        }

        return result
    }

    /// Deduplicated commands matching all selected folders, or all commands if "All" is on.
    private var selectedCommands: [CommandItem] {
        if let pre = prefilledCommands { return pre }
        if selectAll { return allCommands }

        var ids = Set<UUID>()
        var result: [CommandItem] = []

        for (_, items) in groupedItems {
            for item in items where selected.contains(item.id) {
                let matching: [CommandItem]
                switch item.group {
                case .tag:     matching = allCommands.filter { $0.tags.contains(item.value) }
                case .project: matching = allCommands.filter { ($0.project ?? "") == item.value }
                case .tool:    matching = allCommands.filter { ($0.tool ?? "") == item.value }
                }
                for cmd in matching where !ids.contains(cmd.id) {
                    ids.insert(cmd.id)
                    result.append(cmd)
                }
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header — matches AddCommandView
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share Commands")
                        .font(.title3.weight(.semibold))
                    Text(isPrefilled
                         ? "Export selected commands for others"
                         : "Select folders to share — no analytics included")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            if isPrefilled {
                prefilledBody
            } else {
                folderGridBody
            }

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
            }

            // Footer — matches AddCommandView
            Divider()
            HStack(spacing: 10) {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                let count = selectedCommands.count
                if count > 0 {
                    Text("\(count) command\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    exportPack()
                } label: {
                    HStack(spacing: 5) {
                        if isExporting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Export")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedCommands.isEmpty || isExporting)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 440, height: isPrefilled ? 300 : 460)
        .onAppear { if !isPrefilled { loadCommands() } }
    }

    // MARK: - Pre-filled body

    @ViewBuilder
    private var prefilledBody: some View {
        if let label = prefilledLabel {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
        List(prefilledCommands ?? []) { item in
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(item.command)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
            }
            .padding(10)
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            )
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Folder grid body

    private static let gridColumns = [
        GridItem(.adaptive(minimum: 76, maximum: 100), spacing: 6)
    ]

    @ViewBuilder
    private var folderGridBody: some View {
        let groups = groupedItems

        if groups.isEmpty {
            ContentUnavailableView(
                "No tags, projects, or tools",
                systemImage: "tray",
                description: Text("Add tags, projects, or tools to your commands to share them.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── All ──────────────────────────────────
                    sectionHeader("All")

                    LazyVGrid(columns: Self.gridColumns, spacing: 6) {
                        folderCard(
                            title: "All (\(allCommands.count))",
                            isSelected: selectAll
                        ) {
                            selectAll.toggle()
                            if selectAll {
                                selected.removeAll()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)

                    // ── Grouped sections ─────────────────────
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        Divider()
                            .padding(.horizontal, 14)

                        sectionHeader(group.0.rawValue)

                        LazyVGrid(columns: Self.gridColumns, spacing: 6) {
                            ForEach(group.1) { item in
                                let isOn = selected.contains(item.id)
                                folderCard(
                                    title: "\(item.value) (\(item.commandCount))",
                                    isSelected: isOn
                                ) {
                                    toggle(item)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Folder card

    @ViewBuilder
    private func folderCard(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white, Color.accentColor)
                            .offset(x: 3, y: 2)
                    }
                }
                .frame(height: 22)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    // MARK: - Actions

    private func toggle(_ item: ShareSelectableItem) {
        // Deselect "All" when picking individual folders
        selectAll = false
        if selected.contains(item.id) {
            selected.remove(item.id)
        } else {
            selected.insert(item.id)
        }
    }

    private func loadCommands() {
        let repo = CommandRepository()
        allCommands = (try? repo.fetchAll()) ?? []
    }

    private func exportPack() {
        let commands = selectedCommands
        guard !commands.isEmpty else { return }
        isExporting = true

        // Build label and description from selected items
        let selectedItems = groupedItems.flatMap { $0.1 }.filter { selected.contains($0.id) }
        let names = selectedItems.map(\.value)
        let label = names.count <= 3 ? names.joined(separator: "-") : "\(names.count)-items"
        let desc = selectedItems.map { "\($0.group.rawValue.dropLast()): \($0.value)" }.joined(separator: ", ")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try BackupService.exportSharePack(commands: commands, filterDescription: desc)
                DispatchQueue.main.async {
                    isExporting = false
                    onExport(data, label)
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
