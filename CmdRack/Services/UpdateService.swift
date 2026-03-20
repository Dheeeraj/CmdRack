//
//  UpdateService.swift
//  CmdRack
//
//  Wraps Sparkle's SPUUpdater for clean SwiftUI bindings.
//

import Foundation
import Combine
import Sparkle

/// Observable view model that exposes Sparkle's updater state to SwiftUI.
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
