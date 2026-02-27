//
//  GlobalShortcutService.swift
//  CmdRack
//

import Foundation
import AppKit
import Combine

final class GlobalShortcutService: ObservableObject {
    static let shared = GlobalShortcutService()

    @Published var keyCode: UInt16 = 0
    @Published var modifiers: NSEvent.ModifierFlags = []

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var onTrigger: (() -> Void)?

    private static let relevantModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]

    // Default: Control + Shift + Space (unique, not used by any major app)
    private static let defaultKeyCode: UInt16 = 49 // Space
    private static let defaultModifiers: NSEvent.ModifierFlags = [.control, .shift]

    private init() {
        loadShortcut()
    }

    func register(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        startMonitoring()
    }

    func updateShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantModifiers)
        saveShortcut()
        startMonitoring()
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startMonitoring() {
        stopMonitoring()

        guard keyCode != 0, onTrigger != nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matchesShortcut(event) == true {
                self?.handleKeyEvent(event)
                return nil
            }
            return event
        }
    }

    private func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard matchesShortcut(event) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onTrigger?()
        }
    }

    private func matchesShortcut(_ event: NSEvent) -> Bool {
        let eventMods = event.modifierFlags.intersection(Self.relevantModifiers)
        return event.keyCode == keyCode && eventMods == modifiers
    }

    private func saveShortcut() {
        UserDefaults.standard.set(Int(keyCode), forKey: "GlobalShortcutKeyCode")
        UserDefaults.standard.set(Int(modifiers.intersection(Self.relevantModifiers).rawValue), forKey: "GlobalShortcutModifiers")
    }

    private func loadShortcut() {
        let savedKeyCode = UserDefaults.standard.integer(forKey: "GlobalShortcutKeyCode")
        let savedModifiers = UserDefaults.standard.integer(forKey: "GlobalShortcutModifiers")

        if savedKeyCode != 0 {
            keyCode = UInt16(savedKeyCode)
            modifiers = NSEvent.ModifierFlags(rawValue: UInt(savedModifiers)).intersection(Self.relevantModifiers)
        } else {
            keyCode = Self.defaultKeyCode
            modifiers = Self.defaultModifiers
        }
    }

    deinit {
        stopMonitoring()
    }
}
