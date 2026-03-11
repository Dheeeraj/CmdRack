//
//  ShortcutBadge.swift
//  CmdRack
//

import SwiftUI

/// Reusable shortcut key badge (e.g. "1", "q", "M", "=") with consistent styling.
struct ShortcutBadge: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(.caption2, design: .rounded))
            .fontWeight(.medium)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
    }
}
