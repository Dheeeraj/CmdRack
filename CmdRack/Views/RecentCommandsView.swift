//
//  RecentCommandsView.swift
//  CmdRack
//

import SwiftUI
import AppKit

struct RecentCommandsView: View {
    @State private var commands: [CommandItem] = []
    @State private var errorMessage: String?
    @State private var showCopiedAlert = false

    private let repository = CommandRepository()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            if let error = errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            if commands.isEmpty && errorMessage == nil {
                Text("No commands yet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(commands.prefix(5)) { item in
                        CommandRowCompactView(item: item) {
                            showCopiedToast()
                        }
                        if item.id != commands.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .overlay(alignment: .center) {
            if showCopiedAlert {
                Text("Copied")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(1000)
            }
        }
        .onAppear(perform: load)
    }

    private func showCopiedToast() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            closeMenuBarWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showCopiedAlert = false
            }
        }
    }

    private func closeMenuBarWindow() {
        // Close the menu bar popover window (the key window when ContentView is shown)
        NSApp.keyWindow?.close()
    }

    private func load() {
        errorMessage = nil
        do {
            let all = try repository.fetchAll()
            commands = all.sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CommandRowCompactView: View {
    let item: CommandItem
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if item.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            Text(item.command)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            copyCommand()
        }
    }

    private func copyCommand() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.command, forType: .string)
        onCopy()
    }
}

