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
    @State private var showPinnedShortcutsSheet = false
    @State private var showRecentShortcutsSheet = false
    @State private var editPinnedKeys: [String] = []
    @State private var editRecentKeys: [String] = []

    private static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.allowsFloats = false
        f.minimum = 0
        return f
    }()

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

                    Button {
                        NotificationCenter.default.post(name: .cmdRackSwitchToPinnedTab, object: nil)
                    } label: {
                        HStack {
                            Text("Arrange pinned commands")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        editPinnedKeys = settings.pinnedShortcutKeys
                        if editPinnedKeys.count != 10 { editPinnedKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"] }
                        showPinnedShortcutsSheet = true
                    } label: {
                        HStack {
                            Text("Pinned command shortcuts (1–10)")
                            Spacer()
                            Text(settings.pinnedShortcutKeys.prefix(5).joined() + (settings.pinnedShortcutKeys.count > 5 ? "…" : ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        editRecentKeys = settings.recentShortcutKeys
                        if editRecentKeys.count != 10 { editRecentKeys = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"] }
                        showRecentShortcutsSheet = true
                    } label: {
                        HStack {
                            Text("Recent command shortcuts (1–10)")
                            Spacer()
                            Text(settings.recentShortcutKeys.prefix(5).joined() + (settings.recentShortcutKeys.count > 5 ? "…" : ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Menu bar options")
                } footer: {
                    Text("How many commands to show when you open CmdRack from the menu bar (1–10 each). Tap \"Arrange pinned commands\" to open the Commands list on the Pinned tab and drag to reorder. Shortcuts default to 1–0 for pinned and q–p for recent.")
                }

                Section {
                    HStack {
                        Text("Max text length")
                        Spacer()
                        TextField("", value: $settings.commandTextMax, formatter: Self.intFormatter)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                        Text("chars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Max tags per command")
                        Spacer()
                        TextField("", value: $settings.tagMaxCount, formatter: Self.intFormatter)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                        Text("tags")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Max tag length")
                        Spacer()
                        TextField("", value: $settings.tagTextMax, formatter: Self.intFormatter)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                        Text("chars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Command limits")
                } footer: {
                    Text("These limits apply when creating or editing commands. Upper bound is capped to SQLite TEXT max (\(AppSettings.sqliteTextMax)). These settings sync via backup/restore.")
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
        .sheet(isPresented: $showPinnedShortcutsSheet) {
            ShortcutKeysSheetView(
                title: "Pinned shortcuts",
                keys: $editPinnedKeys,
                onDismiss: {
                    showPinnedShortcutsSheet = false
                    if editPinnedKeys.count == 10 {
                        var updated = settings
                        updated.pinnedShortcutKeys = editPinnedKeys
                        updated.save()
                        settings = updated
                    }
                }
            )
        }
        .sheet(isPresented: $showRecentShortcutsSheet) {
            ShortcutKeysSheetView(
                title: "Recent shortcuts",
                keys: $editRecentKeys,
                onDismiss: {
                    showRecentShortcutsSheet = false
                    if editRecentKeys.count == 10 {
                        var updated = settings
                        updated.recentShortcutKeys = editRecentKeys
                        updated.save()
                        settings = updated
                    }
                }
            )
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

// MARK: - Shortcut keys editor sheet
private struct ShortcutKeysSheetView: View {
    let title: String
    @Binding var keys: [String]
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            Divider()
            List {
                ForEach(0..<10, id: \.self) { i in
                    HStack {
                        Text("Slot \(i + 1)")
                            .frame(width: 50, alignment: .leading)
                        SingleKeyRecorderView(key: Binding(
                            get: { keys.indices.contains(i) ? keys[i] : "" },
                            set: { newVal in
                                var copy = keys
                                while copy.count <= i { copy.append("") }
                                copy[i] = newVal
                                keys = copy
                            }
                        ))
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(minWidth: 280, minHeight: 340)
    }
}

#Preview {
    SettingsView()
}
