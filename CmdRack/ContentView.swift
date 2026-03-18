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
    @State private var recentCopiedVersion = 0
    @State private var settings = AppSettings.load()
    @State private var searchShortcutMonitor: Any?

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

    private var hasPinnedSection: Bool {
        allCommands.contains(where: { $0.pinned })
    }

    private var hasRecentSection: Bool {
        _ = recentCopiedVersion // keep computed value in sync with notifications
        guard !allCommands.isEmpty else { return false }
        let allIDs = Set(allCommands.map(\.id))
        return RecentCopiedTracker.shared.ids.contains(where: { allIDs.contains($0) })
    }

    private func searchShortcutRaw(forIndex index: Int) -> String? {
        guard index >= 0, index < 2 else { return nil }
        let keys = settings.searchResultShortcutKeys
        guard keys.count == 2 else { return nil }
        return keys[index]
    }

    private func displayString(forSearchShortcut raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "—" }
        return String(first).lowercased()
    }

    private func startSearchShortcutMonitorIfNeeded() {
        guard searchShortcutMonitor == nil else { return }
        searchShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only when search is open and there are results to act on.
            guard isSearchActive, searchText.count > 1, !searchResults.isEmpty else { return event }

            // No modifiers — keep this truly single-key.
            let mods = event.modifierFlags.intersection([.command, .control, .option, .shift, .function])
            guard mods.isEmpty, let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return event }

            let pressed = String(chars.prefix(1)).lowercased()
            let keys = settings.searchResultShortcutKeys
                .prefix(2)
                .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().prefix(1)) }

            guard keys.count == 2 else { return event }

            if pressed == keys[0] {
                copyAndToast(searchResults[0])
                return nil
            }
            if pressed == keys[1], searchResults.count > 1 {
                copyAndToast(searchResults[1])
                return nil
            }
            return event
        }
    }

    private func stopSearchShortcutMonitor() {
        if let m = searchShortcutMonitor {
            NSEvent.removeMonitor(m)
            searchShortcutMonitor = nil
        }
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
                                ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, item in
                                    let raw = searchShortcutRaw(forIndex: index)
                                    let button = Button {
                                        copyAndToast(item)
                                    } label: {
                                        HStack {
                                            CommandRowCompactView(item: item) { }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                            if let raw {
                                                ShortcutBadge(key: displayString(forSearchShortcut: raw))
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    button
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

            

            if hasPinnedSection && hasRecentSection {
                PinnedCommandsView()
                Divider()
            }
  

            if hasPinnedSection || hasRecentSection {
                RecentCommandsView()
                Divider()
            }

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
                    ShortcutBadge(key: "m")
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
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackRecentCopiedDidChange)) { _ in
            recentCopiedVersion += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackSettingsDidChange)) { _ in
            settings = AppSettings.load()
        }
        .onChange(of: isSearchActive) { _, newValue in
            if newValue {
                startSearchShortcutMonitorIfNeeded()
            } else {
                stopSearchShortcutMonitor()
            }
        }
        .onDisappear {
            stopSearchShortcutMonitor()
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
        AnalyticsService.shared.trackCommandCopied(item)
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
