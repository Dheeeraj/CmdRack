//
//  CmdRackApp.swift
//  CmdRack
//
//  Created by Dheeraj Rao on 09/02/26.
//

import SwiftUI
import AppKit

@main
struct CmdRackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    static let menuBarIcon: NSImage = {
        guard let fullSize = NSImage(named: "MenuBarIcon") else { return NSImage() }
        let targetSize: CGFloat = 22
        let newSize = NSSize(width: targetSize, height: targetSize)
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        fullSize.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: fullSize.size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()
        resized.isTemplate = true
        return resized
    }()

    var body: some Scene {
        Window("CmdRack", id: "manage") {
            ManageDashboardView()
        }
        .defaultSize(width: 720, height: 480)
        .windowResizability(.contentSize)
        .commands { CommandGroup(replacing: .newItem) { } }
        .defaultLaunchBehavior(.suppressed)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupGlobalShortcut()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = CmdRackApp.menuBarIcon
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 260)
        popover.contentViewController = NSHostingController(rootView: ContentView())
    }

    private func setupGlobalShortcut() {
        GlobalShortcutService.shared.register { [weak self] in
            self?.togglePopover(nil)
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(sender)
        }
    }

    private func showPopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

