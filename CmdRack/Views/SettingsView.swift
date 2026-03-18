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
                        Label("Clear all commands", systemImage: "trash")
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

// MARK: - Import Confirmation Sheet

private struct ImportConfirmationSheet: View {
    let metadata: BackupMetadata
    let onImport: (BackupImportMode) -> Void
    let onCancel: () -> Void

    @State private var selectedMode: BackupImportMode = .merge

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .short
        return fmt.string(from: metadata.exportedAt)
    }

    var body: some View {
        VStack(spacing: 0) {

            // Header
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)

                Text("Restore from Snapshot")
                    .font(.headline)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Backup info card
            VStack(alignment: .leading, spacing: 8) {
                metadataRow(icon: "desktopcomputer", label: "Source", value: metadata.deviceName)
                metadataRow(icon: "calendar", label: "Created", value: formattedDate)
                metadataRow(icon: "terminal", label: "Commands", value: "\(metadata.commandCount)")
                metadataRow(icon: "chart.bar", label: "Analytics events", value: "\(metadata.analyticsCount)")
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)

            // Import mode picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Import mode")
                    .font(.subheadline.weight(.medium))
                    .padding(.top, 16)

                ForEach(BackupImportMode.allCases, id: \.self) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedMode == mode ? .blue : .secondary)
                                .font(.body)
                            Image(systemName: mode.icon)
                                .foregroundStyle(mode == .replace ? .orange : .blue)
                                .frame(width: 20, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(mode.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(selectedMode == mode ? Color.accentColor.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            if selectedMode == .replace {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Replace will permanently delete all existing data before restoring.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            Spacer()

            // Action buttons
            Divider()
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(selectedMode == .replace ? "Replace & Restore" : "Merge & Restore") {
                    onImport(selectedMode)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(selectedMode == .replace ? .orange : .blue)
            }
            .padding(16)
        }
        .frame(width: 420, height: 480)
    }

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.caption.weight(.medium))
            Spacer()
        }
    }
}

// MARK: - Shortcut conflict toast

private struct ShortcutConflictToast: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 4)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Shortcut keys editor sheet
private struct ShortcutKeysSheetView: View {
    let title: String
    @Binding var keys: [String]
    var settings: AppSettings
    var group: AppSettings.ShortcutGroup
    var onDismiss: () -> Void

    @State private var conflictMessage: String?
    @State private var dismissTask: DispatchWorkItem?

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

            if let msg = conflictMessage {
                ShortcutConflictToast(message: msg) {
                    clearConflict()
                }
            }

            List {
                ForEach(0..<10, id: \.self) { i in
                    HStack {
                        Text("Slot \(i + 1)")
                            .frame(width: 50, alignment: .leading)
                        SingleKeyRecorderView(
                            key: Binding(
                                get: { keys.indices.contains(i) ? keys[i] : "" },
                                set: { newVal in
                                    var copy = keys
                                    while copy.count <= i { copy.append("") }
                                    copy[i] = newVal
                                    keys = copy
                                }
                            ),
                            conflictCheck: { key in
                                for (idx, existing) in keys.enumerated() where idx != i {
                                    if existing.lowercased() == key.lowercased() {
                                        return "\"\(key)\" is already used in slot \(idx + 1) of this group."
                                    }
                                }
                                return settings.conflictDescription(for: key, excluding: group)
                            },
                            onConflict: { message in
                                showConflict(message)
                            }
                        )
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(minWidth: 280, minHeight: 340)
        .animation(.easeInOut(duration: 0.25), value: conflictMessage != nil)
    }

    private func showConflict(_ message: String) {
        dismissTask?.cancel()
        withAnimation { conflictMessage = message }
        let task = DispatchWorkItem { clearConflict() }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: task)
    }

    private func clearConflict() {
        dismissTask?.cancel()
        withAnimation { conflictMessage = nil }
    }
}

// MARK: - Search result shortcut keys editor (special keys only)
private struct SearchResultShortcutKeysSheetView: View {
    @Binding var keys: [String]
    var settings: AppSettings
    var onDismiss: () -> Void

    @State private var conflictMessage: String?
    @State private var dismissTask: DispatchWorkItem?

    static func summary(for keys: [String]) -> String {
        let safe = (keys.count == 2) ? keys : ["z", "x"]
        let a = safe[0].trimmingCharacters(in: .whitespacesAndNewlines).prefix(1).lowercased()
        let b = safe[1].trimmingCharacters(in: .whitespacesAndNewlines).prefix(1).lowercased()
        return "\(a), \(b)"
    }

    var body: some View {
        let safeKeys: Binding<[String]> = Binding(
            get: { keys.count == 2 ? keys : ["z", "x"] },
            set: { keys = $0 }
        )

        VStack(spacing: 0) {
            HStack {
                Text("Search result shortcuts")
                    .font(.headline)
                Spacer()
                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            if let msg = conflictMessage {
                ShortcutConflictToast(message: msg) {
                    clearConflict()
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("These apply to the first two search results in the popup. Press the key to instantly copy (no modifiers).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(0..<2, id: \.self) { i in
                    HStack(spacing: 12) {
                        Text("Result \(i + 1)")
                            .frame(width: 70, alignment: .leading)
                        SingleKeyRecorderView(
                            key: Binding(
                                get: { safeKeys.wrappedValue[i] },
                                set: { newVal in
                                    var copy = safeKeys.wrappedValue
                                    copy[i] = newVal
                                    safeKeys.wrappedValue = copy
                                }
                            ),
                            conflictCheck: { key in
                                let otherIdx = i == 0 ? 1 : 0
                                if safeKeys.wrappedValue[otherIdx].lowercased() == key.lowercased() {
                                    return "\"\(key)\" is already used in slot \(otherIdx + 1) of this group."
                                }
                                return settings.conflictDescription(for: key, excluding: .search)
                            },
                            onConflict: { message in
                                showConflict(message)
                            }
                        )

                        Spacer()
                    }
                }
            }
            .padding()

            Spacer()
        }
        .frame(minWidth: 420, minHeight: 240)
        .animation(.easeInOut(duration: 0.25), value: conflictMessage != nil)
    }

    private func showConflict(_ message: String) {
        dismissTask?.cancel()
        withAnimation { conflictMessage = message }
        let task = DispatchWorkItem { clearConflict() }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: task)
    }

    private func clearConflict() {
        dismissTask?.cancel()
        withAnimation { conflictMessage = nil }
    }
}

// MARK: - Share Export Sheet

/// A selectable item in the share checklist — represents a tag, project, or tool value.
private struct ShareSelectableItem: Identifiable, Hashable {
    enum Group: String { case tag = "Tags", project = "Projects", tool = "Tools" }
    let group: Group
    let value: String
    let commandCount: Int
    var id: String { "\(group.rawValue):\(value)" }
}

struct ShareExportSheet: View {
    let onExport: (Data, String) -> Void
    let onCancel: () -> Void

    /// Pre-fill with specific commands (bypasses checklist).
    var prefilledCommands: [CommandItem]?
    var prefilledLabel: String?

    @State private var allCommands: [CommandItem] = []
    @State private var selected: Set<String> = []          // item ids
    @State private var selectAll = false                    // "All" folder — includes untagged commands
    @State private var isExporting = false
    @State private var errorMessage: String?

    private var isPrefilled: Bool { prefilledCommands != nil }

    // Build grouped items from all commands
    private var groupedItems: [(ShareSelectableItem.Group, [ShareSelectableItem])] {
        var result: [(ShareSelectableItem.Group, [ShareSelectableItem])] = []

        // Tags
        let tags = Array(Set(allCommands.flatMap(\.tags))).sorted()
        if !tags.isEmpty {
            let items = tags.map { t in
                ShareSelectableItem(group: .tag, value: t, commandCount: allCommands.filter { $0.tags.contains(t) }.count)
            }
            result.append((.tag, items))
        }

        // Projects
        let projects = Array(Set(allCommands.compactMap { $0.project?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })).sorted()
        if !projects.isEmpty {
            let items = projects.map { p in
                ShareSelectableItem(group: .project, value: p, commandCount: allCommands.filter { ($0.project ?? "") == p }.count)
            }
            result.append((.project, items))
        }

        // Tools
        let tools = Array(Set(allCommands.compactMap { $0.tool?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })).sorted()
        if !tools.isEmpty {
            let items = tools.map { t in
                ShareSelectableItem(group: .tool, value: t, commandCount: allCommands.filter { ($0.tool ?? "") == t }.count)
            }
            result.append((.tool, items))
        }

        return result
    }

    /// Deduplicated commands matching all selected folders, or all commands if "All" is on.
    private var selectedCommands: [CommandItem] {
        if let pre = prefilledCommands { return pre }
        if selectAll { return allCommands }

        var ids = Set<UUID>()
        var result: [CommandItem] = []

        for (_, items) in groupedItems {
            for item in items where selected.contains(item.id) {
                let matching: [CommandItem]
                switch item.group {
                case .tag:     matching = allCommands.filter { $0.tags.contains(item.value) }
                case .project: matching = allCommands.filter { ($0.project ?? "") == item.value }
                case .tool:    matching = allCommands.filter { ($0.tool ?? "") == item.value }
                }
                for cmd in matching where !ids.contains(cmd.id) {
                    ids.insert(cmd.id)
                    result.append(cmd)
                }
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header — matches AddCommandView
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share Commands")
                        .font(.title3.weight(.semibold))
                    Text(isPrefilled
                         ? "Export selected commands for others"
                         : "Select folders to share — no analytics included")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            if isPrefilled {
                prefilledBody
            } else {
                folderGridBody
            }

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
            }

            // Footer — matches AddCommandView
            Divider()
            HStack(spacing: 10) {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                let count = selectedCommands.count
                if count > 0 {
                    Text("\(count) command\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    exportPack()
                } label: {
                    HStack(spacing: 5) {
                        if isExporting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Export")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedCommands.isEmpty || isExporting)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 440, height: isPrefilled ? 300 : 460)
        .onAppear { if !isPrefilled { loadCommands() } }
    }

    // MARK: - Pre-filled body

    @ViewBuilder
    private var prefilledBody: some View {
        if let label = prefilledLabel {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
        List(prefilledCommands ?? []) { item in
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(item.command)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
            }
            .padding(10)
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            )
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Folder grid body

    private static let gridColumns = [
        GridItem(.adaptive(minimum: 76, maximum: 100), spacing: 6)
    ]

    @ViewBuilder
    private var folderGridBody: some View {
        let groups = groupedItems

        if groups.isEmpty {
            ContentUnavailableView(
                "No tags, projects, or tools",
                systemImage: "tray",
                description: Text("Add tags, projects, or tools to your commands to share them.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── All ──────────────────────────────────
                    sectionHeader("All")

                    LazyVGrid(columns: Self.gridColumns, spacing: 6) {
                        folderCard(
                            title: "All (\(allCommands.count))",
                            isSelected: selectAll
                        ) {
                            selectAll.toggle()
                            if selectAll {
                                selected.removeAll()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)

                    // ── Grouped sections ─────────────────────
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        Divider()
                            .padding(.horizontal, 14)

                        sectionHeader(group.0.rawValue)

                        LazyVGrid(columns: Self.gridColumns, spacing: 6) {
                            ForEach(group.1) { item in
                                let isOn = selected.contains(item.id)
                                folderCard(
                                    title: "\(item.value) (\(item.commandCount))",
                                    isSelected: isOn
                                ) {
                                    toggle(item)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Folder card

    @ViewBuilder
    private func folderCard(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white, Color.accentColor)
                            .offset(x: 3, y: 2)
                    }
                }
                .frame(height: 22)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    // MARK: - Actions

    private func toggle(_ item: ShareSelectableItem) {
        // Deselect "All" when picking individual folders
        selectAll = false
        if selected.contains(item.id) {
            selected.remove(item.id)
        } else {
            selected.insert(item.id)
        }
    }

    private func loadCommands() {
        let repo = CommandRepository()
        allCommands = (try? repo.fetchAll()) ?? []
    }

    private func exportPack() {
        let commands = selectedCommands
        guard !commands.isEmpty else { return }
        isExporting = true

        // Build label and description from selected items
        let selectedItems = groupedItems.flatMap { $0.1 }.filter { selected.contains($0.id) }
        let names = selectedItems.map(\.value)
        let label = names.count <= 3 ? names.joined(separator: "-") : "\(names.count)-items"
        let desc = selectedItems.map { "\($0.group.rawValue.dropLast()): \($0.value)" }.joined(separator: ", ")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try BackupService.exportSharePack(commands: commands, filterDescription: desc)
                DispatchQueue.main.async {
                    isExporting = false
                    onExport(data, label)
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Share Import Confirmation Sheet

private struct ShareImportConfirmationSheet: View {
    let metadata: BackupService.SharePackMetadata
    let onImport: () -> Void
    let onCancel: () -> Void

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .short
        return fmt.string(from: metadata.exportedAt)
    }

    var body: some View {
        VStack(spacing: 0) {

            // Header — matches AddCommandView / ShareExportSheet
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Shared Commands")
                        .font(.title3.weight(.semibold))
                    Text("Review the command pack before importing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            // Info card
            VStack(alignment: .leading, spacing: 6) {
                metaRow("From", metadata.deviceName)
                metaRow("Created", formattedDate)
                metaRow("Filter", metadata.filterDescription)
                metaRow("Commands", "\(metadata.commandCount)")
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Notes
            VStack(alignment: .leading, spacing: 6) {
                noteRow("No analytics or settings included")
                noteRow("Duplicate commands will be skipped")
                noteRow("Imported commands will not be pinned")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Spacer()

            // Footer — matches AddCommandView / ShareExportSheet
            Divider()
            HStack(spacing: 10) {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Import") { onImport() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 420, height: 340)
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption.weight(.medium))
            Spacer()
        }
    }

    private func noteRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text("·")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
