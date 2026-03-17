//
//  ManageDashboardView.swift
//  CmdRack
//

import SwiftUI
import AppKit

enum DashboardSection: String, CaseIterable {
    case commands = "Commands"
    case activity = "Activity"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .commands: return "list.bullet"
        case .activity: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }
}

struct ManageDashboardView: View {
    @State private var selectedSection: DashboardSection? = .commands
    @State private var refreshCommandsID = 0
    @State private var focusPinnedTab = false

    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: Identifiable {
        case newCommand
        case editCommand(CommandItem)

        var id: String {
            switch self {
            case .newCommand:
                return "new"
            case .editCommand(let item):
                return item.id.uuidString
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List([DashboardSection.commands, .activity], id: \.self, selection: $selectedSection) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section as DashboardSection?)
                }
                .listStyle(.sidebar)

                Divider()

                Button {
                    selectedSection = .settings
                } label: {
                    HStack {
                        Label(DashboardSection.settings.rawValue, systemImage: DashboardSection.settings.icon)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if selectedSection == .settings {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.25))
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .foregroundStyle(
                        selectedSection == .settings
                        ? Color.white
                        : Color.primary
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Outer padding acts as vertical margin without growing the blue highlight
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            Group {
                switch selectedSection ?? .commands {
                case .commands:
                    CommandListView(
                        onEdit: { item in
                            activeSheet = .editCommand(item)
                        },
                        refreshID: refreshCommandsID,
                        focusPinnedTab: $focusPinnedTab
                    )
                case .activity:
                    ActivityView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activeSheet = .newCommand
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newCommand:
                AddCommandView(
                    commandToEdit: nil,
                    onDismiss: { activeSheet = nil },
                    onSave: { refreshCommandsID += 1 }
                )
            case .editCommand(let item):
                AddCommandView(
                    commandToEdit: item,
                    onDismiss: { activeSheet = nil },
                    onSave: { refreshCommandsID += 1 }
                )
            }
        }
        .onAppear {
            bringWindowToFront()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cmdRackSwitchToPinnedTab)) { _ in
            selectedSection = .commands
            focusPinnedTab = true
        }
    }

    private func bringWindowToFront() {
        DispatchQueue.main.async {
            NSApp.windows.first { $0.title == "CmdRack" }?.makeKeyAndOrderFront(nil)
        }
    }
}

#Preview {
    ManageDashboardView()
}
