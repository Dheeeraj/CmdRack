//
//  SettingsView.swift
//  CmdRack
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @StateObject private var shortcutService = GlobalShortcutService.shared
    @State private var keyCode: UInt16 = 0
    @State private var modifiers: NSEvent.ModifierFlags = []
    @State private var hasPermission = false
    @State private var showClearDataConfirmation = false
    @State private var clearDataError: String?
    @State private var settings = AppSettings.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Global shortcut")
                            .font(.subheadline.weight(.medium))
                        Text("Use this shortcut to open CmdRack from anywhere.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        ShortcutRecorderView(keyCode: $keyCode, modifiers: $modifiers)
                            .onChange(of: keyCode) {
                                shortcutService.updateShortcut(keyCode: keyCode, modifiers: modifiers)
                            }
                            .onChange(of: modifiers) {
                                shortcutService.updateShortcut(keyCode: keyCode, modifiers: modifiers)
                            }
                    }
                    .padding(.vertical, 4)

                    if !hasPermission {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text("Accessibility permission required for global shortcuts.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                shortcutService.requestAccessibilityPermission()
                                checkPermission()
                            } label: {
                                Text("Grant Accessibility Access")
                            }
                            .font(.caption)
                        }
                        .padding(.top, 2)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Accessibility access granted.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    }
                } header: {
                    Text("Shortcuts")
                }

                Section {
                    HStack {
                        Text("Pinned commands shown")
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { Double(settings.pinnedDisplayCount) },
                                set: { settings.pinnedDisplayCount = Int($0) }
                            ),
                            in: 1...10,
                            step: 1
                        )
                        .frame(maxWidth: 160)
                        Text("\(settings.pinnedDisplayCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }

                    HStack {
                        Text("Recent commands shown")
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { Double(settings.recentDisplayCount) },
                                set: { settings.recentDisplayCount = Int($0) }
                            ),
                            in: 1...10,
                            step: 1
                        )
                        .frame(maxWidth: 160)
                        Text("\(settings.recentDisplayCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }
                } header: {
                    Text("Menu bar options")
                } footer: {
                    Text("How many commands to show when you open CmdRack from the menu bar (1–10 each).")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Commands storage")
                            .font(.subheadline.weight(.medium))
                        Text("Commands are stored locally in Application Support/CmdRack and never leave your Mac.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    Button(role: .destructive) {
                        showClearDataConfirmation = true
                    } label: {
                        Label("Clear all commands", systemImage: "trash")
                    }
                    .padding(.top, 2)
                } header: {
                    Text("Data")
                }

                Section {
                    SettingsStyleRow(
                        title: "Version",
                        subtitle: "1.0",
                        showChevron: false,
                        action: nil
                    )
                } header: {
                    Text("General")
                }

            }
            .formStyle(.grouped)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            keyCode = shortcutService.keyCode
            modifiers = shortcutService.modifiers
            settings = AppSettings.load()
            checkPermission()
        }
        .onChange(of: settings) { _, newValue in
            newValue.save()
        }
        .alert("Clear all commands?", isPresented: $showClearDataConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear all", role: .destructive) {
                clearAllCommands()
            }
        } message: {
            Text("This will permanently delete every command. You cannot undo this.")
        }
        .alert("Could not clear data", isPresented: Binding(
            get: { clearDataError != nil },
            set: { if !$0 { clearDataError = nil } }
        )) {
            Button("OK") { clearDataError = nil }
        } message: {
            Text(clearDataError ?? "")
        }
    }

    private func clearAllCommands() {
        let repo = CommandRepository()
        do {
            try repo.deleteAll()
        } catch {
            clearDataError = error.localizedDescription
        }
    }

    private func checkPermission() {
        hasPermission = shortcutService.hasAccessibilityPermission
    }
}

#Preview {
    SettingsView()
}
