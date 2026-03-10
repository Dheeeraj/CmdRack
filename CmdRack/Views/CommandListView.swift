//
//  CommandListView.swift
//  CmdRack
//

import SwiftUI

enum CommandListTab: String, CaseIterable {
    case all = "All"
    case pinned = "Pinned"
    case project = "Project"
    case tool = "Tool"
    case tags = "Tags"
}

struct CommandListView: View {
    var onEdit: ((CommandItem) -> Void)?
    var refreshID: Int = 0

    @State private var commands: [CommandItem] = []
    @State private var searchText = ""
    @State private var selectedTab: CommandListTab = .all
    @State private var selectedTag: String?
    @State private var errorMessage: String?
    @State private var commandPendingDelete: CommandItem?
    @State private var showDeleteConfirmation = false

    private let repository = CommandRepository()

    private var tabFilteredCommands: [CommandItem] {
        switch selectedTab {
        case .all:
            return commands
        case .pinned:
            return commands.filter { $0.pinned }
        case .project:
            return commands.filter { ($0.project ?? "").trimmingCharacters(in: .whitespaces) != "" }
        case .tool:
            return commands.filter { ($0.tool ?? "").trimmingCharacters(in: .whitespaces) != "" }
        case .tags:
            if let tag = selectedTag {
                return commands.filter { $0.tags.contains(tag) }
            }
            return commands.filter { !$0.tags.isEmpty }
        }
    }

    private var filteredCommands: [CommandItem] {
        let list = tabFilteredCommands
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return list }
        return list.filter { item in
            item.title.lowercased().contains(query)
                || item.command.lowercased().contains(query)
                || item.tags.contains { $0.lowercased().contains(query) }
                || (item.project?.lowercased().contains(query) ?? false)
                || (item.tool?.lowercased().contains(query) ?? false)
        }
    }

    private var allTags: [String] {
        Array(Set(commands.flatMap(\.tags))).sorted()
    }

    private var tabEmptyTitle: String {
        switch selectedTab {
        case .all: return "No commands"
        case .pinned: return "No pinned commands"
        case .project: return "No commands with a project"
        case .tool: return "No commands with a tool"
        case .tags: return selectedTag == nil ? "No commands with tags" : "No commands with this tag"
        }
    }

    private var tabEmptyIcon: String {
        switch selectedTab {
        case .all: return "terminal"
        case .pinned: return "pin"
        case .project: return "folder"
        case .tool: return "wrench"
        case .tags: return "tag"
        }
    }

    private var tabEmptyMessage: String {
        switch selectedTab {
        case .all: return "Use the + button to add a command."
        case .pinned: return "Pin a command to see it here."
        case .project: return "Add a project name to commands to see them here."
        case .tool: return "Add a tool to commands to see them here."
        case .tags: return selectedTag == nil ? "Add tags to commands to filter by tag." : "No commands use the tag \"\(selectedTag ?? "")\"."
        }
    }

    private var searchPlaceholder: String {
        switch selectedTab {
        case .all: return "Search by title, command, tags, project, or tool"
        case .pinned: return "Search in pinned commands"
        case .project: return "Search in projects"
        case .tool: return "Search in tools"
        case .tags: return selectedTag == nil ? "Search in tagged commands" : "Search in \"\(selectedTag ?? "")\""
        }
    }

    /// Sections for Project / Tool / Tags(All): (group name, commands in that group).
    private var groupedSections: [(String, [CommandItem])] {
        let list = filteredCommands
        switch selectedTab {
        case .all:
            return []
        case .pinned:
            return []
        case .project:
            let grouped = Dictionary(grouping: list) { ($0.project ?? "").trimmingCharacters(in: .whitespaces) }
            return grouped.filter { !$0.key.isEmpty }.map { ($0.key, $0.value) }.sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
        case .tool:
            let grouped = Dictionary(grouping: list) { ($0.tool ?? "").trimmingCharacters(in: .whitespaces) }
            return grouped.filter { !$0.key.isEmpty }.map { ($0.key, $0.value) }.sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
        case .tags:
            if selectedTag != nil { return [] }
            let tagsInList = Array(Set(list.flatMap(\.tags))).sorted()
            return tagsInList.map { tag in (tag, list.filter { $0.tags.contains(tag) }) }
        }
    }

    private var showGroupedSections: Bool {
        switch selectedTab {
        case .all: return false
        case .pinned: return false
        case .project, .tool: return true
        case .tags: return selectedTag == nil && !filteredCommands.isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Search bar (fixed at top)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.body)
                TextField(searchPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Tabs: All, Project, Tool, Tags
            HStack(spacing: 4) {
                ForEach(CommandListTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        if tab != .tags { selectedTag = nil }
                    } label: {
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedTab == tab ? Color.primary.opacity(0.12) : Color.clear)
                            .clipShape(Capsule())
                            // Make the whole pill area (and a bit around) clickable
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2) // slightly taller hit area without changing visual pill
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            // Tag sub-filter (when Tags tab selected)
            if selectedTab == .tags && !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button {
                            selectedTag = nil
                        } label: {
                            Text("All")
                                .font(.caption2)
                                .fontWeight(selectedTag == nil ? .semibold : .regular)
                                .foregroundStyle(selectedTag == nil ? Color.accentColor : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedTag == nil ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        ForEach(allTags, id: \.self) { tag in
                            Button {
                                selectedTag = tag
                            } label: {
                                Text(tag)
                                    .font(.caption2)
                                    .fontWeight(selectedTag == tag ? .semibold : .regular)
                                    .foregroundStyle(selectedTag == tag ? Color.accentColor : .secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(selectedTag == tag ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.bottom, 6)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            if commands.isEmpty && errorMessage == nil {
                ContentUnavailableView(
                    "No commands yet",
                    systemImage: "terminal",
                    description: Text("Use the + button in the toolbar to add a command.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredCommands.isEmpty {
                if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView(
                        tabEmptyTitle,
                        systemImage: tabEmptyIcon,
                        description: Text(tabEmptyMessage)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if showGroupedSections {
                List {
                    ForEach(groupedSections, id: \.0) { groupName, items in
                        Section {
                            ForEach(items) { item in
                                commandRow(item)
                            }
                        } header: {
                            Text("\(groupName) (\(items.count))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                List(filteredCommands) { item in
                    commandRow(item)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadCommands()
        }
        .onChange(of: refreshID) {
            loadCommands()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackCommandsDidChange)) { _ in
            loadCommands()
        }
        .alert("Delete Command?", isPresented: $showDeleteConfirmation, presenting: commandPendingDelete) { item in
            Button("Delete", role: .destructive) {
                delete(item)
            }
            Button("Cancel", role: .cancel) {
                commandPendingDelete = nil
            }
        } message: { item in
            Text("Are you sure you want to delete \"\(item.title)\"?")
        }
    }

    private func commandSubtitle(_ item: CommandItem) -> String {
        if let tool = item.tool, !tool.isEmpty {
            return "\(item.command) · \(tool)"
        }
        return item.command
    }

    @ViewBuilder
    private func commandRow(_ item: CommandItem) -> some View {
        SettingsStyleRow(
            title: item.title,
            subtitle: commandSubtitle(item),
            showChevron: true,
            action: { onEdit?(item) }
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        )
        .listRowSeparator(.hidden)
        .contextMenu {
            if let onEdit {
                Button("Edit") {
                    onEdit(item)
                }
            }
            Button(role: .destructive) {
                commandPendingDelete = item
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func loadCommands() {
        errorMessage = nil
        do {
            let all = try repository.fetchAll()
            commands = all.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ item: CommandItem) {
        do {
            try repository.delete(id: item.id)
            commands.removeAll { $0.id == item.id }
            commandPendingDelete = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CommandListView(onEdit: nil, refreshID: 0)
}
