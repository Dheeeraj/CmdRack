//
//  ClipboardService.swift
//  CmdRack
//

import AppKit

/// Shared clipboard + analytics helper so copy logic isn't duplicated across views.
enum ClipboardService {

    /// Copy a command to the pasteboard, record it as recently copied, track analytics,
    /// then post `cmdRackDismissPopover` after a short delay.
    static func copyAndDismiss(_ item: CommandItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.command, forType: .string)
        RecentCopiedTracker.shared.recordCopy(id: item.id)
        AnalyticsService.shared.trackCommandCopied(item)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .cmdRackDismissPopover, object: nil)
        }
    }
}
