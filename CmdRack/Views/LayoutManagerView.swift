//
//  LayoutManagerView.swift
//  CmdRack
//
//  Layout list + editor for the Manage dashboard.
//

import SwiftUI

// MARK: - Layout list

struct LayoutManagerView: View {
    @State private var settings = AppSettings.load()
    @State private var editingLayout: LayoutConfiguration?
    @State private var showDeleteConfirmation: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Layouts")
                        .font(.title2.weight(.bold))
                    Text("Custom command groups for your popup menu. Use ← → arrow keys to switch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    let newLayout = LayoutConfiguration.create(name: "New Layout")
                    settings.layouts.append(newLayout)
                    editingLayout = newLayout
                } label: {
                    Label("Add Layout", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            if settings.layouts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No layouts yet")
                        .font(.subheadline.weight(.medium))
                    Text("Create a layout to organize commands by tag, project, or tool in your popup menu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(settings.layouts) { layout in
                        layoutRow(layout)
                    }
                    .onMove { from, to in
                        settings.layouts.move(fromOffsets: from, toOffset: to)
                        settings.save()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackSettingsDidChange)) { _ in
            settings = AppSettings.load()
        }
        .sheet(item: $editingLayout) { layout in
            if let idx = settings.layouts.firstIndex(where: { $0.id == layout.id }) {
                LayoutEditorSheet(
                    layout: Binding(
                        get: { settings.layouts[idx] },
                        set: { settings.layouts[idx] = $0 }
                    ),
                    settings: settings,
                    isActive: settings.activeLayoutId == layout.id,
                    onDone: {
                        editingLayout = nil
                        settings.layouts[idx].updatedAt = Date()
                        settings.save()
                    },
                    onCancel: {
                        editingLayout = nil
                        // Reload to discard unsaved changes
                        settings = AppSettings.load()
                    },
                    onSetActive: {
                        settings.activeLayoutId = layout.id
                        settings.save()
                    },
                    onClearActive: {
                        settings.activeLayoutId = nil
                        settings.save()
                    },
                    onDelete: {
                        editingLayout = nil
                        settings.layouts.removeAll { $0.id == layout.id }
                        if settings.activeLayoutId == layout.id {
                            settings.activeLayoutId = nil
                        }
                        settings.save()
                    }
                )
            }
        }
        .alert("Delete Layout?", isPresented: Binding(
            get: { showDeleteConfirmation != nil },
            set: { if !$0 { showDeleteConfirmation = nil } }
        )) {
            Button("Cancel", role: .cancel) { showDeleteConfirmation = nil }
            Button("Delete", role: .destructive) {
                if let id = showDeleteConfirmation {
                    settings.layouts.removeAll { $0.id == id }
                    if settings.activeLayoutId == id {
                        settings.activeLayoutId = nil
                    }
                    settings.save()
                }
                showDeleteConfirmation = nil
            }
        } message: {
            Text("This layout will be permanently deleted.")
        }
    }

    @ViewBuilder
    private func layoutRow(_ layout: LayoutConfiguration) -> some View {
        let isActive = settings.activeLayoutId == layout.id
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(layout.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("\(layout.sections.count) section\(layout.sections.count == 1 ? "" : "s")\(isActive ? " · Active" : "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { editingLayout = layout }
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    isActive
                        ? RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accentColor.opacity(0.08))
                        : nil
                )
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        )
        .listRowSeparator(.hidden)
        .contextMenu {
            Button {
                editingLayout = layout
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            if isActive {
                Button {
                    settings.activeLayoutId = nil
                    settings.save()
                } label: {
                    Label("Remove Active", systemImage: "circle")
                }
            } else {
                Button {
                    settings.activeLayoutId = layout.id
                    settings.save()
                } label: {
                    Label("Set as Active", systemImage: "checkmark.circle")
                }
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirmation = layout.id
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Layout editor sheet

private struct LayoutEditorSheet: View {
    @Binding var layout: LayoutConfiguration
    let settings: AppSettings
    let isActive: Bool
    let onDone: () -> Void
    let onCancel: () -> Void
    let onSetActive: () -> Void
    let onClearActive: () -> Void
    let onDelete: () -> Void

    @State private var allCommands: [CommandItem] = []
    @State private var showAddSection = false
    @State private var showDeleteConfirmation = false
    @State private var showShortcutKeysSheet = false

    // Available filter values from existing commands
    private var availableTags: [String] {
        Array(Set(allCommands.flatMap(\.tags))).sorted()
    }
    private var availableProjects: [String] {
        Array(Set(allCommands.compactMap { $0.project?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })).sorted()
    }
    private var availableTools: [String] {
        Array(Set(allCommands.compactMap { $0.tool?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit Layout")
                        .font(.title3.weight(.semibold))
                    Text("Configure sections and shortcut keys")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Layout Name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("e.g. DevOps, Frontend", text: $layout.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    // Sections
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sections")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                showAddSection = true
                            } label: {
                                Label("Add Section", systemImage: "plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if layout.sections.isEmpty {
                            Text("No sections yet. Add a section to filter commands by tag, project, or tool.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                        } else {
                            List {
                                ForEach(Array(layout.sections.enumerated()), id: \.element.id) { index, section in
                                    SectionEditorRow(
                                        section: Binding(
                                            get: { layout.sections[index] },
                                            set: { layout.sections[index] = $0 }
                                        ),
                                        allCommands: allCommands,
                                        onDelete: {
                                            layout.sections.remove(at: index)
                                        }
                                    )
                                }
                                .onMove { from, to in
                                    layout.sections.move(fromOffsets: from, toOffset: to)
                                }
                            }
                            .listStyle(.plain)
                            .frame(minHeight: CGFloat(layout.sections.count) * 52, maxHeight: 260)
                        }
                    }

                    Divider()

                    // Shortcut keys
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Shortcut Keys")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("Assigned sequentially across sections. Tap to customize.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Button {
                            showShortcutKeysSheet = true
                        } label: {
                            shortcutKeysSummaryRow
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }

            // Footer
            Divider()
            HStack(spacing: 10) {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete layout")

                Button {
                    if isActive { onClearActive() } else { onSetActive() }
                } label: {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .help(isActive ? "Remove as active" : "Set as active")

                Spacer()

                Button("Done") { onDone() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(layout.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 520)
        .alert("Delete Layout?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This layout will be permanently deleted.")
        }
        .onAppear { loadCommands() }
        .sheet(isPresented: $showAddSection) {
            AddSectionSheet(
                availableTags: availableTags,
                availableProjects: availableProjects,
                availableTools: availableTools,
                onAdd: { section in
                    layout.sections.append(section)
                    showAddSection = false
                },
                onCancel: { showAddSection = false }
            )
        }
        .sheet(isPresented: $showShortcutKeysSheet) {
            LayoutShortcutKeysSheet(
                keys: $layout.shortcutKeys,
                settings: settings,
                onDismiss: { showShortcutKeysSheet = false }
            )
        }
    }

    // MARK: - Shortcut keys summary row

    @ViewBuilder
    private var shortcutKeysSummaryRow: some View {
        let totalCommands = countTotalCommands()
        let keyCount = layout.shortcutKeys.count
        let preview = layout.shortcutKeys.prefix(10).joined()

        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(keyCount) shortcut keys · \(totalCommands) commands matched")
                    .font(.caption)
                    .foregroundStyle(.primary)
                Text(preview + (keyCount > 10 ? "…" : ""))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if totalCommands > keyCount {
                Text("+\(totalCommands - keyCount) unassigned")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Helpers

    private func loadCommands() {
        let repo = CommandRepository()
        allCommands = (try? repo.fetchAll()) ?? []
    }

    private func countTotalCommands() -> Int {
        var ids = Set<UUID>()
        for section in layout.sections {
            let matching: [CommandItem]
            switch section.filter {
            case .tag(let tag):
                matching = allCommands.filter { $0.tags.contains(tag) }
            case .project(let project):
                matching = allCommands.filter { ($0.project ?? "") == project }
            case .tool(let tool):
                matching = allCommands.filter { ($0.tool ?? "") == tool }
            }
            for cmd in matching { ids.insert(cmd.id) }
        }
        return ids.count
    }
}

// MARK: - Section editor row

private struct SectionEditorRow: View {
    @Binding var section: LayoutSection
    let allCommands: [CommandItem]
    let onDelete: () -> Void

    private var matchingCount: Int {
        switch section.filter {
        case .tag(let tag):
            return allCommands.filter { $0.tags.contains(tag) }.count
        case .project(let project):
            return allCommands.filter { ($0.project ?? "") == project }.count
        case .tool(let tool):
            return allCommands.filter { ($0.tool ?? "") == tool }.count
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 1) {
                TextField("Section title", text: $section.title)
                    .font(.subheadline.weight(.medium))
                    .textFieldStyle(.plain)
                Text("\(section.filter.typeLabel): \(section.filter.value) · \(matchingCount) commands")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { onDelete() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add section sheet

private enum SectionFilterTab: String, CaseIterable {
    case tag = "Tag"
    case project = "Project"
    case tool = "Tool"
}

private struct AddSectionSheet: View {
    let availableTags: [String]
    let availableProjects: [String]
    let availableTools: [String]
    let onAdd: (LayoutSection) -> Void
    let onCancel: () -> Void

    @State private var selectedTab: SectionFilterTab = .tag
    @State private var selectedValue = ""
    @State private var customTitle = ""
    @State private var searchText = ""

    private var availableValues: [String] {
        switch selectedTab {
        case .tag:     return availableTags
        case .project: return availableProjects
        case .tool:    return availableTools
        }
    }

    private var filteredValues: [String] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return availableValues }
        return availableValues.filter { $0.lowercased().contains(query) }
    }

    private var searchPlaceholder: String {
        switch selectedTab {
        case .tag:     return "Search tags"
        case .project: return "Search projects"
        case .tool:    return "Search tools"
        }
    }

    private var canAdd: Bool {
        !selectedValue.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Section")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                // Search bar
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

                // Tabs
                HStack(spacing: 4) {
                    ForEach(SectionFilterTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                            selectedValue = ""
                            searchText = ""
                        } label: {
                            Text(tab.rawValue)
                                .font(.caption)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedTab == tab ? Color.primary.opacity(0.12) : Color.clear)
                                .clipShape(Capsule())
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

                valueListContent
            }

            // Custom title
            VStack(alignment: .leading, spacing: 4) {
                Text("Section title")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("e.g. Docker Commands", text: $customTitle)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Footer
            Divider()
            HStack(spacing: 10) {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add Section") {
                    let filter: LayoutSectionFilter
                    switch selectedTab {
                    case .tag:     filter = .tag(selectedValue)
                    case .project: filter = .project(selectedValue)
                    case .tool:    filter = .tool(selectedValue)
                    }
                    let title = customTitle.trimmingCharacters(in: .whitespaces).isEmpty
                        ? selectedValue
                        : customTitle
                    let section = LayoutSection(title: title, filter: filter)
                    onAdd(section)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 400, height: 480)
    }

    @ViewBuilder
    private var valueListContent: some View {
        if availableValues.isEmpty {
            let iconName = selectedTab == .tag ? "tag" : selectedTab == .project ? "folder" : "wrench"
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text("No \(selectedTab.rawValue.lowercased())s found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Add a \(selectedTab.rawValue.lowercased()) to your commands first.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredValues.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(filteredValues, id: \.self) { value in
                    valueRow(value)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func valueRow(_ value: String) -> some View {
        let isSelected = selectedValue == value
        HStack(spacing: 10) {
            Text(value)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.03))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        )
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedValue = value
            if customTitle.isEmpty {
                customTitle = value
            }
        }
    }
}

// MARK: - Layout shortcut keys editor

private struct LayoutShortcutKeysSheet: View {
    @Binding var keys: [String]
    let settings: AppSettings
    let onDismiss: () -> Void

    @State private var conflictMessage: String?
    @State private var dismissTask: DispatchWorkItem?

    /// Groups of 10 for visual organisation.
    private let rows = [
        (label: "Row 1", range: 0..<10),
        (label: "Row 2", range: 10..<20),
        (label: "Row 3", range: 20..<30)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Layout Shortcuts")
                        .font(.headline)
                    Text("Up to 30 keys, assigned sequentially across sections.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reset to Default") {
                    keys = LayoutConfiguration.defaultShortcutKeys
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding()

            Divider()

            if let msg = conflictMessage {
                ShortcutConflictToast(message: msg) {
                    clearConflict()
                }
            }

            List {
                ForEach(rows, id: \.label) { group in
                    Section {
                        ForEach(group.range, id: \.self) { i in
                            shortcutRow(index: i)
                        }
                    } header: {
                        Text(group.label)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .frame(width: 340, height: 500)
        .animation(.easeInOut(duration: 0.25), value: conflictMessage != nil)
    }

    @ViewBuilder
    private func shortcutRow(index i: Int) -> some View {
        HStack {
            Text("Slot \(i + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            SingleKeyRecorderView(
                key: Binding(
                    get: { keys.indices.contains(i) ? keys[i] : "" },
                    set: { newVal in
                        var copy = keys
                        while copy.count <= i { copy.append("") }
                        copy[i] = newVal
                        keys = copy
                    }
                ),
                conflictCheck: { key in
                    // Check duplicates within this layout's keys
                    for (idx, existing) in keys.enumerated() where idx != i {
                        if existing.lowercased() == key.lowercased() {
                            return "\"\(key)\" is already used in slot \(idx + 1) of this layout."
                        }
                    }
                    // Check reserved & search conflicts
                    let k = key.lowercased()
                    if AppSettings.reservedKeys.contains(k) {
                        return "\"\(key)\" is reserved by the app."
                    }
                    if let idx = settings.searchResultShortcutKeys.firstIndex(where: { $0.lowercased() == k }) {
                        return "\"\(key)\" is already used by Search result shortcuts (slot \(idx + 1))."
                    }
                    return nil
                },
                onConflict: { message in
                    showConflict(message)
                }
            )
        }
    }

    private func showConflict(_ message: String) {
        dismissTask?.cancel()
        withAnimation { conflictMessage = message }
        let task = DispatchWorkItem { clearConflict() }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: task)
    }

    private func clearConflict() {
        dismissTask?.cancel()
        withAnimation { conflictMessage = nil }
    }
}
