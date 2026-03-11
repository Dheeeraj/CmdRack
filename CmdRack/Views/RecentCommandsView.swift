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
    /// For each row index, return the shortcut key to show and use (e.g. "1", "q"). Nil = no shortcut.
    var shortcutKeyForIndex: (Int) -> String? = { _ in nil }
    var onSelect: (CommandItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let shortcutKey = shortcutKeyForIndex(index)
                    let button = Button {
                        onSelect(item)
                    } label: {
                        HStack {
                            CommandRowCompactView(item: item) { }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            if let key = shortcutKey {
                                ShortcutBadge(key: key)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if let key = shortcutKey, key.count == 1 {
                        button.keyboardShortcut(KeyEquivalent(Character(key)), modifiers: [])
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
    @State private var settings = AppSettings.load()
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
                let recentKeys = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
                CommandListSectionView(
                    title: "Recent",
                    items: recentCommands,
                    shortcutKeyForIndex: { index in
                        guard index < recentKeys.count else { return nil }
                        return recentKeys[index]
                    },
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
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackRecentCopiedDidChange)) { _ in
            load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackSettingsDidChange)) { _ in
            settings = AppSettings.load()
            load()
        }
    }

    /// Loads recently *copied* commands (not recently added).
    /// Uses the tracker's ordered ID list, resolves them from DB, and shows up to recentDisplayCount.
    private func load() {
        errorMessage = nil
        do {
            let copiedIDs = RecentCopiedTracker.shared.ids
            guard !copiedIDs.isEmpty else {
                recentCommands = []
                return
            }
            let allByID = Dictionary(
                uniqueKeysWithValues: try repository.fetchAll().map { ($0.id, $0) }
            )
            recentCommands = copiedIDs
                .compactMap { allByID[$0] }
                .prefix(settings.recentDisplayCount)
                .map { $0 }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyAndToast(_ item: CommandItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.command, forType: .string)
        RecentCopiedTracker.shared.recordCopy(id: item.id)
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
