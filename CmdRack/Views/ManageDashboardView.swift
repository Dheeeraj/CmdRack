//
//  ManageDashboardView.swift
//  CmdRack
//

import SwiftUI
import AppKit

enum DashboardSection: String, CaseIterable {
    case commands = "Commands"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .commands: return "list.bullet"
        case .settings: return "gearshape"
        }
    }
}

struct ManageDashboardView: View {
    @State private var selectedSection: DashboardSection? = .commands
    @State private var showAddCommandSheet = false
    @State private var commandToEdit: CommandItem?
    @State private var refreshCommandsID = 0
    @State private var focusPinnedTab = false

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(
                    DashboardSection.allCases.filter { $0 != .settings },
                    id: \.self,
                    selection: $selectedSection
                ) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
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
                            commandToEdit = item
                            showAddCommandSheet = true
                        },
                        refreshID: refreshCommandsID,
                        focusPinnedTab: $focusPinnedTab
                    )
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        commandToEdit = nil
                        showAddCommandSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddCommandSheet) {
            AddCommandView(
                commandToEdit: commandToEdit,
                onDismiss: {
                    showAddCommandSheet = false
                    commandToEdit = nil
                },
                onSave: {
                    refreshCommandsID += 1
                }
            )
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
