//
//  PinnedCommandsView.swift
//  CmdRack
//

import SwiftUI
import AppKit

struct PinnedCommandsView: View {
    @State private var pinnedCommands: [CommandItem] = []
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

            if !pinnedCommands.isEmpty {
                CommandListSectionView(
                    title: "Pinned",
                    items: pinnedCommands,
                    shortcutKeyForIndex: settings.pinnedShortcutsEnabled ? { index in
                        guard index < settings.pinnedShortcutKeys.count else { return nil }
                        let k = settings.pinnedShortcutKeys[index]
                        return k.isEmpty ? nil : k
                    } : { _ in nil },
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
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackSettingsDidChange)) { _ in
            settings = AppSettings.load()
            load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackPinnedOrderDidChange)) { _ in
            load()
        }
    }

    private func load() {
        errorMessage = nil
        do {
            let all = try repository.fetchAll()
            let pinnedAll = all.filter(\.pinned)
            let ordered = PinnedOrderStore.shared.applyOrder(to: pinnedAll)
            pinnedCommands = Array(ordered.prefix(settings.pinnedDisplayCount))
        } catch {
            errorMessage = error.localizedDescription
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
