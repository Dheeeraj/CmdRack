//
//  SettingsView.swift
//  CmdRack
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @StateObject private var shortcutService = GlobalShortcutService.shared
    @State private var keyCode: UInt16 = 0
    @State private var modifiers: NSEvent.ModifierFlags = [.command]
    
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
                    ShortcutRecorderView(keyCode: $keyCode, modifiers: $modifiers)
                        .onChange(of: keyCode) {
                            shortcutService.updateShortcut(keyCode: keyCode, modifiers: modifiers)
                        }
                        .onChange(of: modifiers) {
                            shortcutService.updateShortcut(keyCode: keyCode, modifiers: modifiers)
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
        }
    }
}

#Preview {
    SettingsView()
}
