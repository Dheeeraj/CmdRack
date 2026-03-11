//
//  RecentCommandsView.swift
//  CmdRack
//

import SwiftUI
import AppKit

// MARK: - Reusable command list section (no per-row dividers; whole section is one block)
struct CommandListSectionView: View {
    let title: String
    let items: [CommandItem]
    var numberShortcuts: Bool = false
    var onSelect: (CommandItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let button = Button {
                        onSelect(item)
                    } label: {
                        CommandRowCompactView(item: item) { }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if numberShortcuts && index < 5 {
                        button.keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
                    } else {
                        button
                    }
                }
            }
        }
    }
}

struct RecentCommandsView: View {
    @State private var recentCommands: [CommandItem] = []
    @State private var errorMessage: String?
    @State private var showCopiedAlert = false

    private let repository = CommandRepository()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            if !recentCommands.isEmpty {
                CommandListSectionView(
                    title: "Recent",
                    items: recentCommands,
                    numberShortcuts: false,
                    onSelect: copyAndToast
                )
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
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackCommandsDidChange)) { _ in
            load()
        }
    }

    // Replace with your own source when not using DB
    private func load() {
        errorMessage = nil
        do {
            let all = try repository.fetchAll()
            let sorted = all.sorted { $0.updatedAt > $1.updatedAt }
            recentCommands = Array(sorted.prefix(3))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyAndToast(_ item: CommandItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.command, forType: .string)
        showCopiedToast()
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
        NSApp.keyWindow?.close()
    }
}

struct CommandRowCompactView: View {
    let item: CommandItem
    var onCopy: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            Text(item.command)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}
