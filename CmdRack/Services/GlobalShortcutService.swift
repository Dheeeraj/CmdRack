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
    @Published var modifiers: NSEvent.ModifierFlags = [.command]
    
    private var eventMonitor: Any?
    private var onTrigger: (() -> Void)?
    
    private init() {
        loadShortcut()
    }
    
    func register(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        startMonitoring()
    }
    
    func updateShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        saveShortcut()
        startMonitoring()
    }
    
    private func startMonitoring() {
        stopMonitoring()
        
        guard keyCode != 0 else { return }
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return }
            
            if event.keyCode == self.keyCode && event.modifierFlags.contains(self.modifiers) {
                DispatchQueue.main.async {
                    self.onTrigger?()
                }
            }
        }
    }
    
    private func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func saveShortcut() {
        UserDefaults.standard.set(keyCode, forKey: "GlobalShortcutKeyCode")
        UserDefaults.standard.set(modifiers.rawValue, forKey: "GlobalShortcutModifiers")
    }
    
    private func loadShortcut() {
        keyCode = UInt16(UserDefaults.standard.integer(forKey: "GlobalShortcutKeyCode"))
        let modifiersValue = UserDefaults.standard.integer(forKey: "GlobalShortcutModifiers")
        modifiers = NSEvent.ModifierFlags(rawValue: UInt(modifiersValue))
        
        // Default to Command+Space if nothing is set
        if keyCode == 0 {
            keyCode = 49 // Space key
            modifiers = [.command]
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
