//
//  ContentView.swift
//  CmdRack
//
//  Created by Dheeraj Rao on 09/02/26.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var searchText = ""
    @State private var isSearchActive = false
    @FocusState private var searchFocused: Bool
    @State private var allCommands: [CommandItem] = []
    @State private var showCopiedAlert = false

    private let repository = CommandRepository()

    private var searchResults: [CommandItem] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count > 1 else { return [] }
        return allCommands.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.command.localizedCaseInsensitiveContains(q) ||
            $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) }) ||
            ($0.tool?.localizedCaseInsensitiveContains(q) ?? false) ||
            ($0.project?.localizedCaseInsensitiveContains(q) ?? false)
        }
        .prefix(2)
        .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Search bar: placeholder mode vs active mode
            if isSearchActive {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Search commands...", text: $searchText)
                            .textFieldStyle(.plain)
                            .focused($searchFocused)
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isSearchActive = false
                                searchText = ""
                                searchFocused = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )

                    // Search results (when user typed more than 1 char)
                    if searchText.count > 1 {
                        if searchResults.isEmpty {
                            Text("No such command. try typing a different command")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(searchResults) { item in
                                    Button {
                                        copyAndToast(item)
                                    } label: {
                                        CommandRowCompactView(item: item) { }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        Divider()
                    }
                }
                .transition(.opacity)
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isSearchActive = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        searchFocused = true
                    }
                } label: {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                            Text("Search")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)

                        Spacer()

                        Text("Tab")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.tab, modifiers: [])
                .transition(.opacity)
            }

            PinnedCommandsView()

            Divider()

            RecentCommandsView()

            Divider()

            Button {
                openWindow(id: "add-command")
            } label: {
                HStack {
                    Text("Add Command")
                    Spacer()
                    ShortcutBadge(key: "=")
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("=", modifiers: [])

            Button {
                openWindow(id: "manage")
            } label: {
                HStack {
                    Text("Manage / Settings")
                    Spacer()
                    ShortcutBadge(key: "M")
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("m", modifiers: [])

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Text("Quit")
                    Spacer()
                    ShortcutBadge(key: "⌫")
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.delete, modifiers: [])
        }
        .padding()
        .frame(width: 340)
        .onAppear(perform: loadCommands)
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackCommandsDidChange)) { _ in
            loadCommands()
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
    }

    private func loadCommands() {
        do {
            allCommands = try repository.fetchAll()
        } catch {
            allCommands = []
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
            NSApp.keyWindow?.close()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showCopiedAlert = false
            }
        }
    }
}

#Preview {
    ContentView()
}
