//
//  AddCommandView.swift
//  CmdRack
//

import SwiftUI
import AppKit

private enum Limits {
    static let textMax   = 1024  // 2^10
    static let tagMax    = 64   // 2^6
    static let tagLen    = 128  // 2^7
}

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

    private let repository = CommandRepository()
    private var isEditMode: Bool { commandToEdit != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isEditMode ? "Edit Command" : "New Command")
                        .font(.title3.weight(.semibold))
                    Text(isEditMode ? "Update an existing command" : "Save a command for quick access")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Pin this")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("", isOn: $pinned)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            // Bento grid
            ScrollView {
                VStack(spacing: 12) {
                    // Row 1: Title + Command (single container)
                    bentoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                fieldLabel("Title", required: true)
                                TextField("e.g. Summon coffee", text: $title)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: title) { title = String(title.prefix(Limits.textMax)) }
                                charCounter(title.count, max: Limits.textMax)
                            }

                            Divider().opacity(0.25)

                            VStack(alignment: .leading, spacing: 4) {
                                fieldLabel("Command", required: true)
                                TextField("e.g. Brew coffee", text: $command)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .onChange(of: command) { command = String(command.prefix(Limits.textMax)) }
                                charCounter(command.count, max: Limits.textMax)
                            }
                        }
                    }

                    // Row 3: Project + Tool (side by side)
                    HStack(spacing: 12) {
                        bentoCard {
                            fieldLabel("Project Name")
                            TextField("e.g. Operation ‘No Bugs’", text: $project)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: project) { project = String(project.prefix(Limits.textMax)) }
                        }
                        bentoCard {
                            fieldLabel("Tool")
                            TextField("e.g. docker, git...", text: $tool)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: tool) { tool = String(tool.prefix(Limits.textMax)) }
                        }
                    }

                    // Row 4: Tags (full width)
                    bentoCard {
                        HStack {
                            fieldLabel("Tags")
                            Spacer()
                            Text("\(tags.count)/\(Limits.tagMax)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(tags.count >= Limits.tagMax ? Color.red : Color.secondary.opacity(0.5))
                        }

                        HStack(spacing: 6) {
                            TextField("Add a tag...", text: $tagInput)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { commitTag() }
                                .onChange(of: tagInput) { tagInput = String(tagInput.prefix(Limits.tagLen)) }

                            Button(action: commitTag) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(
                                        canAddTag ? Color.accentColor : Color.secondary.opacity(0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(!canAddTag)
                        }

                        if !tags.isEmpty {
                            TagCloudView(tags: tags) { removeTag($0) }
                        }
                    }

                    // Metadata info (edit mode only, collapsible)
                    if let item = commandToEdit {
                        metadataSection(item)
                    }
                }
                .padding(16)
            }

            // Validation errors
            if !errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(errors, id: \.self) { err in
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2)
                            Text(err)
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.06))
            }

            Divider()

            // Footer
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

                Button(isEditMode ? "Update" : "Save Command") {
                    saveCommand()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .alert("Delete Command?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteCommand() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            if let item = commandToEdit {
                title   = item.title
                command = item.command
                project = item.project ?? ""
                tool    = item.tool ?? ""
                tags    = item.tags
                pinned  = item.pinned
            }
            if commandToEdit == nil && onDismiss == nil {
                bringWindowToFront()
            }
        }
    }

    // MARK: - Bento card

    private func bentoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func fieldLabel(_ text: String, required: Bool = false) -> some View {
        HStack(spacing: 2) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            if required {
                Text("*")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func charCounter(_ count: Int, max: Int) -> some View {
        Text("\(count)/\(max)")
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(count >= max ? Color.red : Color.secondary.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Tag management

    private var canAddTag: Bool {
        let clean = tagInput.trimmingCharacters(in: .whitespaces)
        return !clean.isEmpty && tags.count < Limits.tagMax
    }

    private func commitTag() {
        let raw = tagInput.trimmingCharacters(in: .whitespaces)
        let newTags = raw.split(separator: ",")
            .map { String($0.trimmingCharacters(in: .whitespaces).prefix(Limits.tagLen)) }
            .filter { !$0.isEmpty && !tags.contains($0) }

        let remaining = Limits.tagMax - tags.count
        tags.append(contentsOf: newTags.prefix(remaining))
        tagInput = ""
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
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
        if title.count > Limits.textMax {
            errs.append("Title exceeds \(Limits.textMax) characters")
        }
        if command.count > Limits.textMax {
            errs.append("Command exceeds \(Limits.textMax) characters")
        }
        if project.count > Limits.textMax {
            errs.append("Project exceeds \(Limits.textMax) characters")
        }
        if tool.count > Limits.textMax {
            errs.append("Tool exceeds \(Limits.textMax) characters")
        }
        if tags.count > Limits.tagMax {
            errs.append("Maximum \(Limits.tagMax) tags allowed")
        }
        if tags.contains(where: { $0.count > Limits.tagLen }) {
            errs.append("Each tag must be \(Limits.tagLen) characters or less")
        }
        return errs
    }

    // MARK: - Metadata display (macOS Settings style)

    @State private var showInfo = false

    private func metadataSection(_ item: CommandItem) -> some View {
        VStack(spacing: 0) {
            // Header row (always visible) — looks like a Settings row
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showInfo.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Info")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text(infoSubtitle(item))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showInfo ? 90 : 0))
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded detail
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
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
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
            onDismiss?()
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
        errors = validate()
        guard errors.isEmpty else { return }

        isSaving = true

        let cleanTitle   = title.trimmingCharacters(in: .whitespaces)
        let cleanCommand = command.trimmingCharacters(in: .whitespaces)
        let now = Date()

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
            onDismiss?()
        } catch {
            errors = [error.localizedDescription]
        }

        isSaving = false
    }
}

// MARK: - Tag Cloud (YouTube-style chips)

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

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .fontWeight(.medium)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.12))
        .foregroundStyle(Color.accentColor)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1))
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
