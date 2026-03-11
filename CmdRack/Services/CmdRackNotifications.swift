//
//  CmdRackNotifications.swift
//  CmdRack
//

import Foundation

extension Notification.Name {
    /// Posted whenever commands data changes (insert/update/delete/clear).
    static let cmdRackCommandsDidChange = Notification.Name("CmdRackCommandsDidChange")

    /// Posted when AppSettings are saved.
    static let cmdRackSettingsDidChange = Notification.Name("CmdRackSettingsDidChange")

    /// Posted when the recently-copied list changes.
    static let cmdRackRecentCopiedDidChange = Notification.Name("CmdRackRecentCopiedDidChange")

    /// Posted when pinned command order is changed (drag/drop).
    static let cmdRackPinnedOrderDidChange = Notification.Name("CmdRackPinnedOrderDidChange")

    /// Posted to switch the manage window to the Commands list with the Pinned tab selected.
    static let cmdRackSwitchToPinnedTab = Notification.Name("CmdRackSwitchToPinnedTab")
}

