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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .padding(.bottom, 8)

            Form {
                Section("General") {
                    LabeledContent("Version", value: "1.0")
                }

                Section("Shortcuts") {
                    LabeledContent("Open CmdRack") {
                        ShortcutRecorderView(keyCode: $keyCode, modifiers: $modifiers)
                            .onChange(of: keyCode) {
                                shortcutService.updateShortcut(keyCode: keyCode, modifiers: modifiers)
                            }
                            .onChange(of: modifiers) {
                                shortcutService.updateShortcut(keyCode: keyCode, modifiers: modifiers)
                            }
                    }

                    if !hasPermission {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text("Accessibility permission required for global shortcuts.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Button("Grant Accessibility Access") {
                                shortcutService.requestAccessibilityPermission()
                                checkPermission()
                            }
                            .font(.caption)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Accessibility access granted.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Data") {
                    Text("Commands are stored in Application Support.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            keyCode = shortcutService.keyCode
            modifiers = shortcutService.modifiers
            checkPermission()
        }
    }

    private func checkPermission() {
        hasPermission = shortcutService.hasAccessibilityPermission
    }
}

#Preview {
    SettingsView()
}
