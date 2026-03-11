//
//  SingleKeyRecorderView.swift
//  CmdRack
//

import SwiftUI
import AppKit
import Combine

/// Records a single key (no modifiers) for menu bar command shortcuts.
struct SingleKeyRecorderView: View {
    @Binding var key: String
    @StateObject private var recorder = SingleKeyRecorderState()

    var body: some View {
        Button {
            if recorder.isRecording {
                recorder.stop()
            } else {
                recorder.startRecording(key: $key)
            }
        } label: {
            Text(recorder.isRecording ? "Press key..." : (key.isEmpty ? "—" : key))
                .font(.system(.caption, design: .monospaced))
                .frame(minWidth: 44, alignment: .center)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(recorder.isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onDisappear { recorder.stop() }
    }
}

private final class SingleKeyRecorderState: ObservableObject {
    @Published var isRecording = false
    private var monitor: Any?

    func startRecording(key: Binding<String>) {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard mods.isEmpty, let chars = event.characters, !chars.isEmpty else { return event }
            let char = String(chars.prefix(1))
            DispatchQueue.main.async {
                key.wrappedValue = char
                self?.stop()
            }
            return nil
        }
    }

    func stop() {
        isRecording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}
