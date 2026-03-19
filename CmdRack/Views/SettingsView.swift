//
//  SettingsView.swift
//  CmdRack
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var shortcutService = GlobalShortcutService.shared
    @State private var keyCode: UInt16 = 0
    @State private var modifiers: NSEvent.ModifierFlags = []
    @State private var hasPermission = false
    @State private var showClearDataConfirmation = false
    @State private var showClearActivityConfirmation = false
    @State private var clearDataError: String?
    @State private var settings = AppSettings.load()
    @State private var settingsSaveTask: DispatchWorkItem?
    @State private var suppressSave = true  // Skip the first onChange triggered by onAppear

    // Backup / Restore
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingImportData: Data?
    @State private var pendingImportMeta: BackupMetadata?
    @State private var backupResultMessage: String?
    @State private var backupErrorMessage: String?

    // Share packs
    @State private var showShareExportSheet = false
    @State private var isShareExporting = false
    @State private var isShareImporting = false
    @State private var pendingShareData: Data?
    @State private var pendingShareMeta: BackupService.SharePackMetadata?

    // Shortcut editors
    @State private var showPinnedShortcutsSheet = false
    @State private var showRecentShortcutsSheet = false
    @State private var showSearchShortcutsSheet = false
    @State private var editPinnedKeys: [String] = []
    @State private var editRecentKeys: [String] = []
    @State private var editSearchKeys: [String] = []

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

                // ── 1. General ──────────────────────────────────────
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

                // ── 2. Shortcuts ────────────────────────────────────
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

                // ── 3. Menu bar options ─────────────────────────────
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

                    Button {
                        editSearchKeys = settings.searchResultShortcutKeys
                        if editSearchKeys.count != 2 { editSearchKeys = ["z", "x"] }
                        showSearchShortcutsSheet = true
                    } label: {
                        HStack {
                            Text("Search result shortcuts (2)")
                            Spacer()
                            Text(SearchResultShortcutKeysSheetView.summary(for: settings.searchResultShortcutKeys))
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
                    Text("How many commands to show when you open CmdRack from the menu bar (1–10 each). Tap \"Arrange pinned commands\" to open the Commands list on the Pinned tab and drag to reorder. Shortcuts default to 1–0 for pinned and q–p for recent. Search result shortcuts are always two single keys (no modifiers).")
                }

                // ── 4. Command limits ───────────────────────────────
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


                // ── 5b. Share Commands ────────────────────────────────
                Section {
                    // --- Share Export ---
                    Button {
                        showShareExportSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Share Commands")
                                    .font(.subheadline.weight(.medium))
                                Text("Export commands by tag, project, or tool — no analytics included.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if isShareExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isShareExporting)

                    // --- Share Import ---
                    Button {
                        chooseShareImportFile()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import Shared Commands")
                                    .font(.subheadline.weight(.medium))
                                Text("Open a .cmds file from a friend. Duplicates are skipped automatically.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if isShareImporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isShareImporting)
                } header: {
                    Text("Share Commands")
                } footer: {
                    Text("Share packs contain only commands — no analytics, settings, or usage data. Duplicate commands (same command text) are skipped on import.")
                }

                                // ── 5. Backup & Restore ─────────────────────────────
                Section {
                    // --- Export ---
                    Button {
                        exportBackup()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.up.doc")
                                .font(.body)
                                .foregroundStyle(.blue)
                                .frame(width: 24, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create Snapshot")
                                    .font(.subheadline.weight(.medium))
                                Text("Save all commands, settings, and activity to a compressed .cmdrack file.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isExporting)

                    // --- Import ---
                    Button {
                        chooseImportFile()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down.doc")
                                .font(.body)
                                .foregroundStyle(.green)
                                .frame(width: 24, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Restore from Snapshot")
                                    .font(.subheadline.weight(.medium))
                                Text("Open a .cmdrack file to restore data on this Mac.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if isImporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)
                } header: {
                    Text("Backup & Restore")
                } footer: {
                    Text("Snapshots are compressed and use the .cmdrack extension. Share the file across Macs to migrate your setup.")
                }

                // ── 6. Data management ──────────────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Local storage")
                            .font(.subheadline.weight(.medium))
                        Text("All data is stored locally in Application Support/CmdRack and never leaves your Mac unless you export a snapshot.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    Button(role: .destructive) {
                        showClearDataConfirmation = true
                    } label: {
                        Label("Clear all data", systemImage: "trash")
                    }
                    .padding(.top, 2)
                } header: {
                    Text("Data")
                }

                // ── 7. Debug ────────────────────────────────────────
                Section {
                    Toggle("Force-unlock Activity tab (debug)", isOn: $settings.debugUnlockActivityTab)
                } header: {
                    Text("Debug")
                } footer: {
                    Text("For development only. When enabled, the Activity tab is available immediately without waiting 3 days after first install.")
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
            // Allow onChange to start saving after the initial load settles
            DispatchQueue.main.async { suppressSave = false }
        }
        .onChange(of: settings) { _, newValue in
            guard !suppressSave else { return }
            // Debounce saves so slider drags don't fire on every tick
            settingsSaveTask?.cancel()
            let task = DispatchWorkItem { newValue.save() }
            settingsSaveTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
        }

        // MARK: - Alerts

        .alert("Clear all data?", isPresented: $showClearDataConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear all", role: .destructive) {
                clearCommandsAndLayouts()
                showClearActivityConfirmation = true
            }
        } message: {
            Text("This will permanently delete all commands and layouts. You cannot undo this.")
        }
        .alert("Also clear activity data?", isPresented: $showClearActivityConfirmation) {
            Button("Keep Activity", role: .cancel) { }
            Button("Clear Activity", role: .destructive) {
                clearActivityData()
            }
        } message: {
            Text("Activity data tracks your command usage and copy history. Would you like to clear it too?")
        }
        .alert("Could not clear data", isPresented: Binding(
            get: { clearDataError != nil },
            set: { if !$0 { clearDataError = nil } }
        )) {
            Button("OK") { clearDataError = nil }
        } message: {
            Text(clearDataError ?? "")
        }
        .alert("Snapshot Saved", isPresented: Binding(
            get: { backupResultMessage != nil },
            set: { if !$0 { backupResultMessage = nil } }
        )) {
            Button("Done") { backupResultMessage = nil }
        } message: {
            Text(backupResultMessage ?? "")
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { backupErrorMessage != nil },
            set: { if !$0 { backupErrorMessage = nil } }
        )) {
            Button("OK") { backupErrorMessage = nil }
        } message: {
            Text(backupErrorMessage ?? "")
        }

        // MARK: - Sheets

        .sheet(isPresented: $showPinnedShortcutsSheet) {
            ShortcutKeysSheetView(
                title: "Pinned shortcuts",
                keys: $editPinnedKeys,
                settings: settings,
                group: .pinned,
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
                settings: settings,
                group: .recent,
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
        .sheet(isPresented: $showSearchShortcutsSheet) {
            SearchResultShortcutKeysSheetView(
                keys: $editSearchKeys,
                settings: settings,
                onDismiss: {
                    showSearchShortcutsSheet = false
                    if editSearchKeys.count == 2 {
                        var updated = settings
                        updated.searchResultShortcutKeys = editSearchKeys
                        updated.save()
                        settings = updated
                    }
                }
            )
        }
        .sheet(item: $pendingImportMeta) { meta in
            ImportConfirmationSheet(
                metadata: meta,
                onImport: { mode in
                    pendingImportMeta = nil
                    performImport(mode: mode)
                },
                onCancel: {
                    pendingImportMeta = nil
                    pendingImportData = nil
                }
            )
        }
        .sheet(isPresented: $showShareExportSheet) {
            ShareExportSheet(
                onExport: { data, label in
                    showShareExportSheet = false
                    presentShareSavePanel(data: data, label: label)
                },
                onCancel: { showShareExportSheet = false }
            )
        }
        .sheet(item: $pendingShareMeta) { meta in
            ShareImportConfirmationSheet(
                metadata: meta,
                onImport: {
                    pendingShareMeta = nil
                    performShareImport()
                },
                onCancel: {
                    pendingShareMeta = nil
                    pendingShareData = nil
                }
            )
        }
    }

    // MARK: - Helpers

    private func clearCommandsAndLayouts() {
        let repo = CommandRepository()
        do {
            try repo.deleteAll()
            // Clear layouts and active layout
            settings.layouts = []
            settings.activeLayoutId = nil
            settings.save()
        } catch {
            clearDataError = error.localizedDescription
        }
    }

    private func clearActivityData() {
        do {
            try DatabaseService.shared.deleteAllAnalyticsEvents()
        } catch {
            clearDataError = error.localizedDescription
        }
    }

    private func checkPermission() {
        hasPermission = shortcutService.hasAccessibilityPermission
    }

    // MARK: - Export

    private func exportBackup() {
        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try BackupService.exportBackup()
                DispatchQueue.main.async {
                    isExporting = false
                    presentSavePanel(data: data)
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    backupErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func presentSavePanel(data: Data) {
        let panel = NSSavePanel()
        panel.title = "Save CmdRack Snapshot"
        panel.message = "Choose where to save your backup snapshot."
        panel.nameFieldStringValue = BackupService.defaultFileName
        panel.allowedContentTypes = [.data]          // .cmdrack is arbitrary binary
        panel.allowsOtherFileTypes = false
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Ensure the .cmdrack extension
        var finalURL = url
        if finalURL.pathExtension != BackupService.fileExtension {
            finalURL = finalURL.deletingPathExtension().appendingPathExtension(BackupService.fileExtension)
        }

        do {
            try data.write(to: finalURL, options: .atomic)
            let sizeKB = data.count / 1024
            backupResultMessage = "Snapshot saved to \(finalURL.lastPathComponent) (\(sizeKB) KB)."
        } catch {
            backupErrorMessage = "Failed to save file: \(error.localizedDescription)"
        }
    }

    // MARK: - Import

    private func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.title = "Open CmdRack Snapshot"
        panel.message = "Select a .cmdrack backup file to restore."
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Soft-check extension
        if url.pathExtension.lowercased() != BackupService.fileExtension {
            backupErrorMessage = "Please select a file with the .\(BackupService.fileExtension) extension."
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let meta = try BackupService.peekMetadata(from: data)
            pendingImportData = data
            pendingImportMeta = meta
        } catch {
            backupErrorMessage = error.localizedDescription
        }
    }

    private func performImport(mode: BackupImportMode) {
        guard let data = pendingImportData else { return }
        pendingImportData = nil
        pendingImportMeta = nil
        isImporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try BackupService.importBackup(from: data, mode: mode)
                DispatchQueue.main.async {
                    isImporting = false
                    settings = AppSettings.load()
                    backupResultMessage = result.summary
                }
            } catch {
                DispatchQueue.main.async {
                    isImporting = false
                    backupErrorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Share Pack Export

    private func presentShareSavePanel(data: Data, label: String) {
        let panel = NSSavePanel()
        panel.title = "Save Shared Commands"
        panel.message = "Choose where to save the command pack."
        panel.nameFieldStringValue = BackupService.shareFileName(label: label)
        panel.allowedContentTypes = [.data]
        panel.allowsOtherFileTypes = false
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var finalURL = url
        if finalURL.pathExtension != BackupService.shareExtension {
            finalURL = finalURL.deletingPathExtension().appendingPathExtension(BackupService.shareExtension)
        }

        do {
            try data.write(to: finalURL, options: .atomic)
            let sizeKB = max(1, data.count / 1024)
            backupResultMessage = "Share pack saved to \(finalURL.lastPathComponent) (\(sizeKB) KB)."
        } catch {
            backupErrorMessage = "Failed to save file: \(error.localizedDescription)"
        }
    }

    // MARK: - Share Pack Import

    private func chooseShareImportFile() {
        let panel = NSOpenPanel()
        panel.title = "Open Shared Command Pack"
        panel.message = "Select a .cmds file to import commands."
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if url.pathExtension.lowercased() != BackupService.shareExtension {
            backupErrorMessage = "Please select a file with the .\(BackupService.shareExtension) extension."
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let meta = try BackupService.peekShareMetadata(from: data)
            pendingShareData = data
            pendingShareMeta = meta
        } catch {
            backupErrorMessage = error.localizedDescription
        }
    }

    private func performShareImport() {
        guard let data = pendingShareData else { return }
        pendingShareData = nil
        pendingShareMeta = nil
        isShareImporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let count = try BackupService.importSharePack(from: data)
                DispatchQueue.main.async {
                    isShareImporting = false
                    if count > 0 {
                        backupResultMessage = "Imported \(count) new command\(count == 1 ? "" : "s"). Duplicates were skipped."
                    } else {
                        backupResultMessage = "No new commands to import — all commands already exist."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isShareImporting = false
                    backupErrorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
