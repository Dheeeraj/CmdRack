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
    private static let menuBarIcon: NSImage = {
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
        MenuBarExtra {
            ContentView()
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.window)

        Window("CmdRack", id: "manage") {
            ManageDashboardView()
        }
        .defaultSize(width: 720, height: 480)
        .windowResizability(.contentSize)
        .commandsRemoved()
    }
}

