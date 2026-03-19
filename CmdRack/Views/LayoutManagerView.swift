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
                        LayoutRowView(
                            layout: layout,
                            isActive: settings.activeLayoutId == layout.id,
                            onEdit: {
                                editingLayout = layout
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
                                showDeleteConfirmation = layout.id
                            }
                        )
                    }
                    .onMove { from, to in
                        settings.layouts.move(fromOffsets: from, toOffset: to)
                        settings.save()
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
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
                    onDone: {
                        editingLayout = nil
                        settings.layouts[idx].updatedAt = Date()
                        settings.save()
                    },
                    onCancel: {
                        editingLayout = nil
                        // Reload to discard unsaved changes
                        settings = AppSettings.load()
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
}

// MARK: - Layout row

private struct LayoutRowView: View {
    let layout: LayoutConfiguration
    let isActive: Bool
    let onEdit: () -> Void
    let onSetActive: () -> Void
    let onClearActive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(layout.name)
                        .font(.subheadline.weight(.medium))
                    if isActive {
                        Text("Active")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green, in: Capsule())
                    }
                }
                Text("\(layout.sections.count) section\(layout.sections.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if isActive { onClearActive() } else { onSetActive() }
            } label: {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isActive ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(isActive ? "Deactivate layout" : "Set as active layout")

            Button { onEdit() } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit layout")

            Button { onDelete() } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Delete layout")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Layout editor sheet

private struct LayoutEditorSheet: View {
    @Binding var layout: LayoutConfiguration
    let settings: AppSettings
    let onDone: () -> Void
    let onCancel: () -> Void

    @State private var allCommands: [CommandItem] = []
    @State private var showAddSection = false

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

                    // Shortcut keys summary
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Shortcut Keys")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        let totalCommands = countTotalCommands()
                        let keyCount = layout.shortcutKeys.count

                        Text("Shortcuts are assigned sequentially across sections. First command gets \"\(layout.shortcutKeys.first ?? "1")\", and so on.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 4) {
                            Text("\(keyCount) keys configured")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("\(totalCommands) commands matched")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if totalCommands > keyCount {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text("\(totalCommands - keyCount) command\(totalCommands - keyCount == 1 ? "" : "s") will show without shortcuts.")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .padding(20)
            }

            // Footer
            Divider()
            HStack(spacing: 10) {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
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
    }

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

private struct AddSectionSheet: View {
    let availableTags: [String]
    let availableProjects: [String]
    let availableTools: [String]
    let onAdd: (LayoutSection) -> Void
    let onCancel: () -> Void

    @State private var filterType: FilterType = .tag
    @State private var selectedValue = ""
    @State private var customTitle = ""

    private enum FilterType: String, CaseIterable {
        case tag = "Tag"
        case project = "Project"
        case tool = "Tool"
    }

    private var availableValues: [String] {
        switch filterType {
        case .tag:     return availableTags
        case .project: return availableProjects
        case .tool:    return availableTools
        }
    }

    private var canAdd: Bool {
        !selectedValue.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Section")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // Filter type
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filter by")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $filterType) {
                        ForEach(FilterType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: filterType) { _, _ in
                        selectedValue = ""
                    }
                }

                // Value picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select \(filterType.rawValue.lowercased())")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if availableValues.isEmpty {
                        Text("No \(filterType.rawValue.lowercased())s found in your commands.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(availableValues, id: \.self) { value in
                                    Button {
                                        selectedValue = value
                                        if customTitle.isEmpty {
                                            customTitle = value
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: selectedValue == value ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedValue == value ? .blue : .secondary)
                                                .font(.body)
                                            Text(value)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(
                                            selectedValue == value
                                                ? Color.accentColor.opacity(0.08)
                                                : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 6)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 160)
                    }
                }

                // Custom title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Section title")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Docker Commands", text: $customTitle)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(20)

            Spacer()

            Divider()
            HStack(spacing: 10) {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add Section") {
                    let filter: LayoutSectionFilter
                    switch filterType {
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
        .frame(width: 400, height: 440)
    }
}
