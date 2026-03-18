//
//  AddCommandView.swift
//  CmdRack
//

import SwiftUI
import AppKit

struct AddCommandView: View {
    var commandToEdit: CommandItem?
    var onDismiss: (() -> Void)?
    var onSave: (() -> Void)?

    @State private var title = ""
    @State private var command = ""
    @State private var project = ""
    @State private var tool = ""
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @State private var pinned = false
    @State private var errors: [String] = []
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var settings = AppSettings.load()
    @State private var appeared = false

    @FocusState private var focusedField: FormField?

    private enum FormField: Hashable {
        case title, command, project, tool, tag
    }

    private let repository = CommandRepository()
    private var isEditMode: Bool { commandToEdit != nil }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            formContent
            if !errors.isEmpty { errorBanner }
            Divider()
            footerSection
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .alert("Delete Command?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteCommand() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            settings = AppSettings.load()
            applyCommandToEdit()
            if commandToEdit == nil && onDismiss == nil {
                bringWindowToFront()
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.05)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focusedField = .title
            }
        }
        .onChange(of: commandToEdit?.id) { _, _ in
            applyCommandToEdit()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackSettingsDidChange)) { _ in
            settings = AppSettings.load()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isEditMode ? "Edit Command" : "New Command")
                    .font(.title3.weight(.semibold))
                Text(isEditMode ? "Modify your saved command" : "Save a command for quick access")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Pin toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    pinned.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: pinned ? "pin.fill" : "pin")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(pinned ? Color.orange : .secondary)
                        .rotationEffect(.degrees(pinned ? 0 : 45))
                    Text(pinned ? "Pinned" : "Pin")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(pinned ? Color.orange : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(pinned ? Color.orange.opacity(0.12) : Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(pinned ? Color.orange.opacity(0.25) : Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Form Content

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // ── Title & Command ──────────────────────────
                cardContainer {
                    VStack(spacing: 0) {
                        fieldRow(
                            label: "Title",
                            placeholder: "Give your command a name",
                            text: $title,
                            field: .title,
                            maxChars: settings.commandTextMax,
                            required: true
                        )

                        Divider().padding(.horizontal, 14)

                        fieldRow(
                            label: "Command",
                            placeholder: "The command to run",
                            text: $command,
                            field: .command,
                            maxChars: settings.commandTextMax,
                            required: true,
                            monospaced: true
                        )
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)

                // ── Project & Tool ──────────────────────────
                HStack(spacing: 12) {
                    cardContainer {
                        fieldRow(
                            label: "Project",
                            placeholder: "Project name",
                            text: $project,
                            field: .project,
                            maxChars: settings.commandTextMax
                        )
                    }

                    cardContainer {
                        fieldRow(
                            label: "Tool",
                            placeholder: "docker, git…",
                            text: $tool,
                            field: .tool,
                            maxChars: settings.commandTextMax
                        )
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)

                // ── Tags ──────────────────────────
                cardContainer {
                    VStack(alignment: .leading, spacing: 0) {
                        // Tag input row
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Text("Tags")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(tags.count)/\(settings.tagMaxCount)")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(tags.count >= settings.tagMaxCount ? .red : .secondary.opacity(0.4))
                                }

                                TextField("Add tags, comma separated…", text: $tagInput)
                                    .textFieldStyle(.plain)
                                    .font(.subheadline)
                                    .focused($focusedField, equals: .tag)
                                    .onSubmit { commitTag() }
                                    .onChange(of: tagInput) { tagInput = String(tagInput.prefix(settings.tagTextMax)) }
                            }

                            Button(action: commitTag) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(canAddTag ? Color.accentColor : Color.secondary.opacity(0.25))
                            }
                            .buttonStyle(.plain)
                            .disabled(!canAddTag)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        if !tags.isEmpty {
                            Divider().padding(.horizontal, 14)

                            TagCloudView(tags: tags) { removeTag($0) }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .transition(.opacity)
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)

                // ── Metadata (edit mode) ──────────────────────────
                if let item = commandToEdit {
                    metadataSection(item)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Card Container

    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }

    // MARK: - Field Row

    private func fieldRow(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: FormField,
        maxChars: Int,
        required: Bool = false,
        monospaced: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                if required {
                    Text("*")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red.opacity(0.7))
                }
                Spacer()
                if focusedField == field && !text.wrappedValue.isEmpty {
                    Text("\(text.wrappedValue.count)/\(maxChars)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(text.wrappedValue.count >= maxChars ? .red : .secondary.opacity(0.3))
                        .transition(.opacity)
                }
            }

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(monospaced ? .system(.subheadline, design: .monospaced) : .subheadline)
                .focused($focusedField, equals: field)
                .onChange(of: text.wrappedValue) { text.wrappedValue = String(text.wrappedValue.prefix(maxChars)) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = field }
    }

    // MARK: - Error Banner

    private var errorBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(errors, id: \.self) { err in
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 5, height: 5)
                    Text(err)
                        .font(.caption)
                }
                .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.06))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 10) {
            Button("Cancel") {
                if let onDismiss {
                    onDismiss()
                } else {
                    closeWindow()
                }
            }
            .keyboardShortcut(.cancelAction)

            if isEditMode {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            Spacer()

            Button {
                saveCommand()
            } label: {
                HStack(spacing: 5) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isEditMode ? "Update" : "Save Command")
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || title.trimmingCharacters(in: .whitespaces).isEmpty || command.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Data

    private func applyCommandToEdit() {
        if let item = commandToEdit {
            title = item.title
            command = item.command
            project = item.project ?? ""
            tool = item.tool ?? ""
            tags = item.tags
            pinned = item.pinned
        } else {
            title = ""
            command = ""
            project = ""
            tool = ""
            tagInput = ""
            tags = []
            pinned = false
            errors = []
        }
    }

    // MARK: - Tag management

    private var canAddTag: Bool {
        let clean = tagInput.trimmingCharacters(in: .whitespaces)
        return !clean.isEmpty && tags.count < settings.tagMaxCount
    }

    private func commitTag() {
        let raw = tagInput.trimmingCharacters(in: .whitespaces)
        let newTags = raw.split(separator: ",")
            .map { String($0.trimmingCharacters(in: .whitespaces).prefix(settings.tagTextMax)) }
            .filter { !$0.isEmpty && !tags.contains($0) }

        let remaining = settings.tagMaxCount - tags.count
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            tags.append(contentsOf: newTags.prefix(remaining))
        }
        tagInput = ""
    }

    private func removeTag(_ tag: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            tags.removeAll { $0 == tag }
        }
    }

    // MARK: - Validation

    private func validate() -> [String] {
        var errs: [String] = []
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            errs.append("Title is required")
        }
        if command.trimmingCharacters(in: .whitespaces).isEmpty {
            errs.append("Command is required")
        }
        if title.count > settings.commandTextMax {
            errs.append("Title exceeds \(settings.commandTextMax) characters")
        }
        if command.count > settings.commandTextMax {
            errs.append("Command exceeds \(settings.commandTextMax) characters")
        }
        if project.count > settings.commandTextMax {
            errs.append("Project exceeds \(settings.commandTextMax) characters")
        }
        if tool.count > settings.commandTextMax {
            errs.append("Tool exceeds \(settings.commandTextMax) characters")
        }
        if tags.count > settings.tagMaxCount {
            errs.append("Maximum \(settings.tagMaxCount) tags allowed")
        }
        if tags.contains(where: { $0.count > settings.tagTextMax }) {
            errs.append("Each tag must be \(settings.tagTextMax) characters or less")
        }
        return errs
    }

    // MARK: - Metadata display

    @State private var showInfo = false

    private func metadataSection(_ item: CommandItem) -> some View {
        cardContainer {
            VStack(spacing: 0) {
                SettingsStyleRow(
                    title: "Info",
                    subtitle: infoSubtitle(item),
                    chevronRotated: showInfo,
                    showChevron: true,
                    action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showInfo.toggle()
                        }
                    }
                )

                if showInfo {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        if let created = item.metadata.first(where: { $0.type == .create }) {
                            metadataDetailRow("Created", date: formatMetadataDate(created.createdUTC), device: created.device)
                        } else {
                            metadataDetailRow("Created", date: formatDate(item.createdAt), device: nil)
                        }

                        if let lastUpdate = item.metadata.last(where: { $0.type == .update }) {
                            metadataDetailRow("Last updated", date: formatMetadataDate(lastUpdate.createdUTC), device: lastUpdate.device)
                        } else if item.updatedAt != item.createdAt {
                            metadataDetailRow("Last updated", date: formatDate(item.updatedAt), device: nil)
                        }

                        let edits = item.metadata.filter { $0.type == .update }.count
                        if edits > 0 {
                            metadataDetailRow("Total edits", date: "\(edits)", device: nil)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func infoSubtitle(_ item: CommandItem) -> String {
        let edits = item.metadata.filter { $0.type == .update }.count
        if let created = item.metadata.first(where: { $0.type == .create }) {
            let date = formatMetadataDate(created.createdUTC)
            return edits > 0 ? "Created \(date) · \(edits) edit\(edits == 1 ? "" : "s")" : "Created \(date)"
        }
        return "Created \(formatDate(item.createdAt))"
    }

    private func metadataDetailRow(_ label: String, date: String, device: String?) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(date)
                    .font(.caption)
                    .fontWeight(.medium)
                if let device {
                    Text(device)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private static let localDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()

    private static let iso8601Parser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private func formatMetadataDate(_ utcString: String) -> String {
        guard let date = Self.iso8601Parser.date(from: utcString) else {
            return utcString
        }
        return Self.localDateFormatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        Self.localDateFormatter.string(from: date)
    }

    // MARK: - Delete

    private func deleteCommand() {
        guard let item = commandToEdit else { return }
        do {
            try repository.delete(id: item.id)
            onSave?()
            if let onDismiss {
                onDismiss()
            } else {
                closeWindow()
            }
        } catch {
            errors = [error.localizedDescription]
        }
    }

    // MARK: - Helpers

    private func bringWindowToFront() {
        DispatchQueue.main.async {
            NSApp.windows.first { $0.title == "Add Command" }?.makeKeyAndOrderFront(nil)
        }
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }

    private func saveCommand() {
        withAnimation(.easeOut(duration: 0.2)) {
            errors = validate()
        }
        guard errors.isEmpty else { return }

        isSaving = true

        let cleanTitle   = title.trimmingCharacters(in: .whitespaces)
        let cleanCommand = command.trimmingCharacters(in: .whitespaces)
        let now = Date()

        // Dispatch to next run-loop tick so SwiftUI can render the spinner
        DispatchQueue.main.async {
            do {
                if let existing = commandToEdit {
                    var updated = existing
                    updated.title     = cleanTitle
                    updated.command   = cleanCommand
                    updated.tags      = tags
                    updated.project   = project.isEmpty ? nil : project.trimmingCharacters(in: .whitespaces)
                    updated.tool      = tool.isEmpty    ? nil : tool.trimmingCharacters(in: .whitespaces)
                    updated.pinned    = pinned
                    updated.updatedAt = now
                    updated.metadata.append(CommandMetadataEntry.make(type: .update, date: now))
                    try repository.update(updated)
                } else {
                    let item = CommandItem(
                        id: UUID(),
                        title:     cleanTitle,
                        command:   cleanCommand,
                        tags:      tags,
                        metadata:  [CommandMetadataEntry.make(type: .create, date: now)],
                        project:   project.isEmpty ? nil : project.trimmingCharacters(in: .whitespaces),
                        tool:      tool.isEmpty    ? nil : tool.trimmingCharacters(in: .whitespaces),
                        pinned:    pinned,
                        createdAt: now,
                        updatedAt: now
                    )
                    try repository.insert(item)
                }
                onSave?()
                if let onDismiss {
                    onDismiss()
                } else {
                    closeWindow()
                }
            } catch {
                errors = [error.localizedDescription]
            }
            isSaving = false
        }
    }
}

// MARK: - Tag Cloud

struct TagCloudView: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                TagChipView(tag: tag) { onRemove(tag) }
            }
        }
    }
}

struct TagChipView: View {
    let tag: String
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .fontWeight(.medium)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isHovering ? .primary : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(isHovering ? 0.10 : 0.06))
        .foregroundStyle(.primary)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    AddCommandView()
}
