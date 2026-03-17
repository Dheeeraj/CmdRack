//
//  ActivityView.swift
//  CmdRack
//

import SwiftUI

struct ActivityView: View {
    @State private var settings = AppSettings.load()
    @State private var totalOpens: Int = 0
    @State private var opensViaShortcut: Int = 0
    @State private var opensViaClick: Int = 0
    @State private var dailyOpens: [DailyCount] = []
    @State private var topCommandsWeek: [CommandUsageSummary] = []
    @State private var topCommandsAll: [CommandUsageSummary] = []
    @State private var topTagsWeek: [StringUsageSummary] = []
    @State private var topToolsWeek: [StringUsageSummary] = []
    @State private var topProjectsWeek: [StringUsageSummary] = []

    private let analytics = AnalyticsService.shared

    private var isUnlocked: Bool {
        settings.debugUnlockActivityTab || Calendar.current.dateComponents(
            [.day],
            from: settings.firstRunDate,
            to: Date()
        ).day.map { $0 >= 3 } ?? false
    }

    private var unlockDateText: String {
        let unlockDate = Calendar.current.date(byAdding: .day, value: 3, to: settings.firstRunDate) ?? settings.firstRunDate
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: unlockDate)
    }

    var body: some View {
        Group {
            if !isUnlocked {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Activity will be available soon")
                        .font(.title3.weight(.semibold))
                    Text("We’ll unlock this tab after 3 days of usage so there’s enough data to show meaningful insights.\n\nEstimated unlock: \(unlockDateText).")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 360)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        overviewSection
                        popoverSection
                        topCommandsSection
                        topDimensionsSection
                    }
                    .padding(20)
                }
            }
        }
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackSettingsDidChange)) { _ in
            settings = AppSettings.load()
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.headline)
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Popover opens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(totalOpens)")
                        .font(.title3.weight(.semibold))
                }
                VStack(alignment: .leading) {
                    Text("Via shortcut")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(opensViaShortcut)")
                        .font(.subheadline.weight(.medium))
                }
                VStack(alignment: .leading) {
                    Text("Via menu bar click")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(opensViaClick)")
                        .font(.subheadline.weight(.medium))
                }
                VStack(alignment: .leading) {
                    Text("Tracking since")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDate(settings.firstRunDate))
                        .font(.subheadline.weight(.medium))
                }
            }
        }
        .cardBackground()
    }

    private var popoverSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Popover opens · last 7 days")
                .font(.headline)
            if dailyOpens.isEmpty {
                Text("No data yet. Use CmdRack for a few days and check back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dailyOpens, id: \.date) { day in
                    HStack {
                        Text(shortDate(day.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        GeometryReader { geo in
                            let maxCount = max(dailyOpens.map(\.count).max() ?? 1, 1)
                            let width = CGFloat(day.count) / CGFloat(maxCount) * geo.size.width
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.06))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentColor.opacity(0.45))
                                    .frame(width: max(width, 4))
                            }
                        }
                        .frame(height: 10)
                        Text("\(day.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 26, alignment: .trailing)
                    }
                }
            }
        }
        .cardBackground()
    }

    private var topCommandsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most copied commands")
                .font(.headline)
            if topCommandsWeek.isEmpty && topCommandsAll.isEmpty {
                Text("Copy some commands to see your most-used ones.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                if !topCommandsWeek.isEmpty {
                    Text("Last 7 days")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(topCommandsWeek, id: \.command.id) { summary in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(summary.command.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(summary.command.command)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("×\(summary.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !topCommandsAll.isEmpty {
                    Divider().padding(.vertical, 4)
                    Text("All time")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(topCommandsAll, id: \.command.id) { summary in
                        HStack {
                            Text(summary.command.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text("×\(summary.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .cardBackground()
    }

    private var topDimensionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top by tag / tool / project (last 7 days)")
                .font(.headline)
            HStack(alignment: .top, spacing: 16) {
                usageList(title: "Tags", items: topTagsWeek)
                usageList(title: "Tools", items: topToolsWeek)
                usageList(title: "Projects", items: topProjectsWeek)
            }
        }
        .cardBackground()
    }

    private func usageList(title: String, items: [StringUsageSummary]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(items.prefix(5), id: \.key) { item in
                    HStack {
                        Text(item.key)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("×\(item.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func reload() {
        settings = AppSettings.load()
        totalOpens = analytics.totalPopoverOpens()
        opensViaShortcut = analytics.totalPopoverOpensViaShortcut()
        opensViaClick = analytics.totalPopoverOpensViaClick()
        dailyOpens = analytics.dailyPopoverOpens(lastDays: 7)
        topCommandsWeek = analytics.mostCopiedCommands(lastDays: 7, limit: 5)
        topCommandsAll = analytics.mostCopiedCommands(lastDays: nil, limit: 5)
        topTagsWeek = analytics.topTags(lastDays: 7, limit: 5)
        topToolsWeek = analytics.topTools(lastDays: 7, limit: 5)
        topProjectsWeek = analytics.topProjects(lastDays: 7, limit: 5)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

private extension View {
    func cardBackground() -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }
}

