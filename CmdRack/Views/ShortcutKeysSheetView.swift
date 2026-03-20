//
//  ShortcutKeysSheetView.swift
//  CmdRack
//

import SwiftUI

// MARK: - Shortcut keys editor sheet (pinned / recent)

struct ShortcutKeysSheetView: View {
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

struct SearchResultShortcutKeysSheetView: View {
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
