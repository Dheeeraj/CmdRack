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
    @State private var totalCommandsCopied: Int = 0
    @State private var commandsCopiedWeek: Int = 0
    @State private var dailyOpens: [DailyCount] = []
    @State private var dailyCopies: [DailyCount] = []
    @State private var topCommandsWeek: [CommandUsageSummary] = []
    @State private var topCommandsAll: [CommandUsageSummary] = []
    @State private var topTagsWeek: [StringUsageSummary] = []
    @State private var topToolsWeek: [StringUsageSummary] = []
    @State private var topProjectsWeek: [StringUsageSummary] = []
    @State private var appeared = false

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

    private var shortcutPercentage: Double {
        guard totalOpens > 0 else { return 0 }
        return Double(opensViaShortcut) / Double(totalOpens) * 100
    }

    private var daysSinceInstall: Int {
        max(Calendar.current.dateComponents([.day], from: settings.firstRunDate, to: Date()).day ?? 0, 0)
    }

    private var avgDailyOpens: Double {
        guard daysSinceInstall > 0 else { return Double(totalOpens) }
        return Double(totalOpens) / Double(daysSinceInstall)
    }

    var body: some View {
        Group {
            if !isUnlocked {
                lockedView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        headerSection
                        statsCardsRow
                        HStack(alignment: .top, spacing: 14) {
                            popoverChartSection
                            copiesChartSection
                        }
                        topCommandsSection
                        topDimensionsSection
                    }
                    .padding(20)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
            }
        }
        .onAppear {
            reload()
            withAnimation(.easeOut(duration: 0.4).delay(0.05)) {
                appeared = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackSettingsDidChange)) { _ in
            settings = AppSettings.load()
        }
    }

    // MARK: - Locked View

    private var lockedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Activity will be available soon")
                .font(.title3.weight(.semibold))
            Text("We'll unlock this tab after 3 days of usage so there's enough data to show meaningful insights.\n\nEstimated unlock: \(unlockDateText).")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Activity")
                    .font(.title2.weight(.bold))
                Text("Tracking since \(formatDate(settings.firstRunDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Stats Cards Row

    private var statsCardsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            StatCard(
                icon: "rectangle.expand.vertical",
                label: "Total Opens",
                value: "\(totalOpens)",
                color: .blue
            )
            StatCard(
                icon: "keyboard",
                label: "Via Shortcut",
                value: "\(opensViaShortcut)",
                detail: totalOpens > 0 ? "\(Int(shortcutPercentage))%" : nil,
                color: .purple
            )
            StatCard(
                icon: "cursorarrow.click.2",
                label: "Via Click",
                value: "\(opensViaClick)",
                color: .orange
            )
            StatCard(
                icon: "doc.on.doc",
                label: "Commands Copied",
                value: "\(totalCommandsCopied)",
                detail: commandsCopiedWeek > 0 ? "\(commandsCopiedWeek) this week" : nil,
                color: .green
            )
        }
    }

    // MARK: - Popover Chart

    private var popoverChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Popover Opens")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Last 7 days")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if dailyOpens.isEmpty {
                emptyChartPlaceholder
            } else {
                barChart(data: dailyOpens, color: .blue)
            }
        }
        .analyticsCard()
    }

    // MARK: - Copies Chart

    private var copiesChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Commands Copied")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Last 7 days")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if dailyCopies.isEmpty {
                emptyChartPlaceholder
            } else {
                barChart(data: dailyCopies, color: .green)
            }
        }
        .analyticsCard()
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar")
                .font(.title3)
                .foregroundStyle(.quaternary)
            Text("Not enough data yet")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    private func barChart(data: [DailyCount], color: Color) -> some View {
        let maxCount = max(data.map(\.count).max() ?? 1, 1)
        return VStack(spacing: 6) {
            ForEach(data, id: \.date) { day in
                HStack(spacing: 8) {
                    Text(shortDate(day.date))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .leading)
                    GeometryReader { geo in
                        let width = CGFloat(day.count) / CGFloat(maxCount) * geo.size.width
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color.opacity(0.08))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color.opacity(0.5))
                                .frame(width: max(width, 3))
                        }
                    }
                    .frame(height: 8)
                    Text("\(day.count)")
                        .font(.caption2.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Top Commands

    private var topCommandsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Most Copied Commands")
                .font(.subheadline.weight(.semibold))

            if topCommandsWeek.isEmpty && topCommandsAll.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "square.on.square.dashed")
                            .font(.title3)
                            .foregroundStyle(.quaternary)
                        Text("Copy some commands to see your favorites here")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    if !topCommandsWeek.isEmpty {
                        commandRankingList(title: "This Week", items: topCommandsWeek, showCommand: true)
                    }
                    if !topCommandsWeek.isEmpty && !topCommandsAll.isEmpty {
                        Divider()
                    }
                    if !topCommandsAll.isEmpty {
                        commandRankingList(title: "All Time", items: topCommandsAll, showCommand: false)
                    }
                }
            }
        }
        .analyticsCard()
    }

    private func commandRankingList(title: String, items: [CommandUsageSummary], showCommand: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(items.enumerated()), id: \.element.command.id) { index, summary in
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: 14, alignment: .center)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(summary.command.title)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        if showCommand {
                            Text(summary.command.command)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text("\(summary.count)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Top Dimensions

    private var topDimensionsSection: some View {
        HStack(alignment: .top, spacing: 14) {
            dimensionCard(title: "Top Tags", icon: "tag", items: topTagsWeek, color: .blue)
            dimensionCard(title: "Top Tools", icon: "wrench", items: topToolsWeek, color: .orange)
            dimensionCard(title: "Top Projects", icon: "folder", items: topProjectsWeek, color: .purple)
        }
    }

    private func dimensionCard(title: String, icon: String, items: [StringUsageSummary], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.7))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                Text("No data")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                let maxCount = items.first?.count ?? 1
                ForEach(items.prefix(5), id: \.key) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.key)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        GeometryReader { geo in
                            let width = maxCount > 0 ? CGFloat(item.count) / CGFloat(maxCount) * geo.size.width : 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color.opacity(0.3))
                                .frame(width: max(width, 3))
                        }
                        .frame(height: 3)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .analyticsCard()
    }

    // MARK: - Data Loading

    private func reload() {
        settings = AppSettings.load()
        totalOpens = analytics.totalPopoverOpens()
        opensViaShortcut = analytics.totalPopoverOpensViaShortcut()
        opensViaClick = analytics.totalPopoverOpensViaClick()
        totalCommandsCopied = analytics.totalCommandsCopied()
        commandsCopiedWeek = analytics.totalCommandsCopied(lastDays: 7)
        dailyOpens = analytics.dailyPopoverOpens(lastDays: 7)
        dailyCopies = analytics.dailyCommandCopies(lastDays: 7)
        topCommandsWeek = analytics.mostCopiedCommands(lastDays: 7, limit: 5)
        topCommandsAll = analytics.mostCopiedCommands(lastDays: nil, limit: 5)
        topTagsWeek = analytics.topTags(lastDays: 7, limit: 5)
        topToolsWeek = analytics.topTools(lastDays: 7, limit: 5)
        topProjectsWeek = analytics.topProjects(lastDays: 7, limit: 5)
    }

    // MARK: - Helpers

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.mediumDateFormatter.string(from: date)
    }

    private func shortDate(_ date: Date) -> String {
        Self.shortDayFormatter.string(from: date)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    var detail: String? = nil
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.7))
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(detail ?? " ")
                .font(.caption2)
                .foregroundColor(detail != nil ? .secondary.opacity(0.5) : .clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .analyticsCard()
    }
}

// MARK: - Card Modifier

private extension View {
    func analyticsCard() -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
    }
}
