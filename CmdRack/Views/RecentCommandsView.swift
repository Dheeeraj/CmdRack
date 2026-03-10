//
//  RecentCommandsView.swift
//  CmdRack
//

import SwiftUI
import AppKit

struct RecentCommandsView: View {
    @State private var pinnedCommands: [CommandItem] = []
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

            // Pinned (up to 5)
            if !pinnedCommands.isEmpty {
                sectionHeader("Pinned")
                commandRows(pinnedCommands, numberShortcuts: true)
            }

            // Recent (up to 3)
            if !recentCommands.isEmpty {
                sectionHeader("Recent")
                commandRows(recentCommands, numberShortcuts: false)
            }

            if pinnedCommands.isEmpty && recentCommands.isEmpty && errorMessage == nil {
                Text("No commands yet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func commandRows(_ items: [CommandItem], numberShortcuts: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let button = Button {
                    copyAndToast(item)
                } label: {
                    CommandRowCompactView(item: item) { }
                }
                .buttonStyle(.plain)

                if numberShortcuts && index < 5 {
                    button.keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
                } else {
                    button
                }

                if index < items.count - 1 {
                    Divider()
                }
            }
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

    private func load() {
        errorMessage = nil
        do {
            let all = try repository.fetchAll()
            let sorted = all.sorted { $0.updatedAt > $1.updatedAt }
            pinnedCommands = sorted.filter(\.pinned).prefix(5).map { $0 }
            recentCommands = Array(sorted.prefix(3))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CommandRowCompactView: View {
    let item: CommandItem
    var onCopy: (() -> Void)? = nil

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
    }
}
