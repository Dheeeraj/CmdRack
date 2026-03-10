//
//  CmdRackNotifications.swift
//  CmdRack
//

import Foundation

extension Notification.Name {
    /// Posted whenever commands data changes (insert/update/delete/clear).
    static let cmdRackCommandsDidChange = Notification.Name("CmdRackCommandsDidChange")
}

