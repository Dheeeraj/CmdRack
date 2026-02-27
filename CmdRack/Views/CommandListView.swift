//
//  CommandListView.swift
//  CmdRack
//

import SwiftUI

struct CommandListView: View {
    var onEdit: ((CommandItem) -> Void)?
    var refreshID: Int = 0

    @State private var commands: [CommandItem] = []
    @State private var errorMessage: String?
    @State private var commandPendingDelete: CommandItem?
    @State private var showDeleteConfirmation = false

    private let repository = CommandRepository()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

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
            } else {
                List(commands) { item in
                    HStack {
                        CommandRowView(item: item)
                        Spacer()
                        HStack(spacing: 4) {
                            if let onEdit {
                                Button {
                                    onEdit(item)
                                } label: {
                                    Image(systemName: "square.and.pencil")
                                }
                                .buttonStyle(.borderless)
                            }
                            Button {
                                commandPendingDelete = item
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadCommands()
        }
        .onChange(of: refreshID) {
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

    private func loadCommands() {
        errorMessage = nil
        do {
            commands = try repository.fetchAll()
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

struct CommandRowView: View {
    let item: CommandItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.title)
                    .font(.headline)
                if item.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(item.command)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let tool = item.tool, !tool.isEmpty {
                Text(tool)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CommandListView(onEdit: nil, refreshID: 0)
}
