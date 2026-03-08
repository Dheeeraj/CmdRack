//
//  SettingsStyleRow.swift
//  CmdRack
//

import SwiftUI

/// Reusable row in macOS Settings style: title, subtitle, and optional chevron.
/// Tap opens the primary action (e.g. edit). Use in lists or cards.
struct SettingsStyleRow: View {
    var title: String
    var subtitle: String
    /// When true, chevron is rotated 90° (e.g. expanded state).
    var chevronRotated: Bool = false
    var showChevron: Bool = true
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(chevronRotated ? 90 : 0))
                }
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Card-wrapped version: same row style inside a rounded card with optional border.
struct SettingsStyleRowCard<Content: View>: View {
    var title: String
    var subtitle: String
    var chevronRotated: Bool = false
    var showChevron: Bool = true
    var action: (() -> Void)?
    @ViewBuilder var expandedContent: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            SettingsStyleRow(
                title: title,
                subtitle: subtitle,
                chevronRotated: chevronRotated,
                showChevron: showChevron,
                action: action
            )

            expandedContent()
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Convenience initializers

extension SettingsStyleRowCard where Content == EmptyView {
    init(
        title: String,
        subtitle: String,
        chevronRotated: Bool = false,
        showChevron: Bool = true,
        action: (() -> Void)?
    ) {
        self.title = title
        self.subtitle = subtitle
        self.chevronRotated = chevronRotated
        self.showChevron = showChevron
        self.action = action
        self.expandedContent = { EmptyView() }
    }
}

#Preview("Row only") {
    VStack(spacing: 0) {
        SettingsStyleRow(
            title: "Wi-Fi",
            subtitle: "Connected",
            action: { }
        )
        SettingsStyleRow(
            title: "Build project",
            subtitle: "xcodebuild -scheme App",
            action: { }
        )
    }
    .frame(width: 320)
    .padding()
}
