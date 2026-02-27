//
//  AddCommandView.swift
//  CmdRack
//

import SwiftUI
import AppKit

struct AddCommandView: View {
    /// When set, form is in edit mode; when nil, form is for adding a new command.
    var commandToEdit: CommandItem?
    /// Called when sheet should close (e.g. Cancel or after Save).
    var onDismiss: (() -> Void)?
    /// Called after a successful save (add or update).
    var onSave: (() -> Void)?

    @State private var title = ""
    @State private var command = ""
    @State private var project = ""
    @State private var tool = ""
    @State private var tagsText = ""
    @State private var pinned = false
    @State private var errorMessage: String?
    @State private var isSaving = false

    private let repository = CommandRepository()
    private var isEditMode: Bool { commandToEdit != nil }

    private var tags: [String] {
        tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditMode ? "Edit Command" : "New Command")
                .font(.headline)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("Command", text: $command)
                .textFieldStyle(.roundedBorder)

            TextField("Project (optional)", text: $project)
                .textFieldStyle(.roundedBorder)

            TextField("Tool (optional)", text: $tool)
                .textFieldStyle(.roundedBorder)

            TextField("Tags (comma-separated)", text: $tagsText)
                .textFieldStyle(.roundedBorder)

            Toggle("Pinned", isOn: $pinned)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    if let onDismiss {
                        onDismiss()
                    } else {
                        closeWindow()
                    }
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditMode ? "Update" : "Save") {
                    saveCommand()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving || title.isEmpty || command.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 360)
        .onAppear {
            if let item = commandToEdit {
                title = item.title
                command = item.command
                project = item.project ?? ""
                tool = item.tool ?? ""
                tagsText = item.tags.joined(separator: ", ")
                pinned = item.pinned
            }
            if commandToEdit == nil && onDismiss == nil {
                bringWindowToFront()
            }
        }
    }

    private func bringWindowToFront() {
        DispatchQueue.main.async {
            NSApp.windows.first { $0.title == "Add Command" }?.makeKeyAndOrderFront(nil)
        }
    }

    private func saveCommand() {
        guard !title.isEmpty, !command.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        let now = Date()

        if let existing = commandToEdit {
            var updated = existing
            updated.title = title.trimmingCharacters(in: .whitespaces)
            updated.command = command.trimmingCharacters(in: .whitespaces)
            updated.tags = tags
            updated.project = project.isEmpty ? nil : project.trimmingCharacters(in: .whitespaces)
            updated.tool = tool.isEmpty ? nil : tool.trimmingCharacters(in: .whitespaces)
            updated.pinned = pinned
            updated.updatedAt = now
            do {
                try repository.update(updated)
                onSave?()
                onDismiss?()
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            let item = CommandItem(
                id: UUID(),
                title: title.trimmingCharacters(in: .whitespaces),
                command: command.trimmingCharacters(in: .whitespaces),
                tags: tags,
                project: project.isEmpty ? nil : project.trimmingCharacters(in: .whitespaces),
                tool: tool.isEmpty ? nil : tool.trimmingCharacters(in: .whitespaces),
                pinned: pinned,
                createdAt: now,
                updatedAt: now
            )
            do {
                try repository.insert(item)
                onSave?()
                onDismiss?()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}

#Preview {
    AddCommandView()
}
