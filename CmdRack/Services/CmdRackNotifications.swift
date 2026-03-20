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

    /// Posted when the active layout changes (arrow key navigation in the popup).
    static let cmdRackLayoutDidChange = Notification.Name("CmdRackLayoutDidChange")

    /// Posted by views that want to dismiss the menu bar popover (instead of using NSApp.keyWindow?.close()).
    static let cmdRackDismissPopover = Notification.Name("CmdRackDismissPopover")
}

