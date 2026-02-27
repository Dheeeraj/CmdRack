//
//  ShortcutRecorderView.swift
//  CmdRack
//

import SwiftUI
import AppKit

struct ShortcutRecorderView: View {
    @Binding var keyCode: UInt16
    @Binding var modifiers: NSEvent.ModifierFlags
    
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    
    var body: some View {
        HStack {
            Text("Global Shortcut:")
                .frame(width: 120, alignment: .leading)
            
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? "Press keys..." : formatShortcut(keyCode: keyCode, modifiers: modifiers))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
            guard isRecording else { return event }
            
            let pressedModifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            
            // Require at least one modifier key
            guard !pressedModifiers.isEmpty else {
                return event
            }
            
            DispatchQueue.main.async {
                keyCode = event.keyCode
                modifiers = pressedModifiers
                isRecording = false
                stopRecording()
            }
            
            return nil // Consume the event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func formatShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        
        if modifiers.contains(.command) {
            parts.append("⌘")
        }
        if modifiers.contains(.control) {
            parts.append("⌃")
        }
        if modifiers.contains(.option) {
            parts.append("⌥")
        }
        if modifiers.contains(.shift) {
            parts.append("⇧")
        }
        
        let keyName = keyCodeToName(keyCode)
        parts.append(keyName)
        
        return parts.joined(separator: " ")
    }
    
    private func keyCodeToName(_ code: UInt16) -> String {
        switch code {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Esc"
        case 126: return "↑"
        case 125: return "↓"
        case 123: return "←"
        case 124: return "→"
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        default: return "Key \(code)"
        }
    }
}
