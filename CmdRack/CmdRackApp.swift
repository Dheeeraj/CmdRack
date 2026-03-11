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

        Window("Add Command", id: "add-command") {
            AddCommandView()
        }
        .defaultSize(width: 520, height: 520)
        .windowResizability(.contentSize)
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

        // Bring the app to foreground before showing the popover.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // After showing, ensure the popover window is key and the content
        // view (not the TextField) is the first responder.
        // Two passes: immediate + delayed, to handle the first-launch case
        // where the app isn't fully activated yet.
        activatePopoverWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.activatePopoverWindow()
        }
    }

    private func activatePopoverWindow() {
        guard let vc = popover.contentViewController,
              let window = vc.view.window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(vc.view)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

