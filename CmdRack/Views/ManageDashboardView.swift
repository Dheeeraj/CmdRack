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

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(
                    DashboardSection.allCases.filter { $0 != .settings },
                    id: \.self,
                    selection: $selectedSection
                ) { section in
                    NavigationLink(value: section) {
                        Label(section.rawValue, systemImage: section.icon)
                    }
                }
                .listStyle(.sidebar)

                Divider()

                Button {
                    selectedSection = .settings
                } label: {
                    Label("Settings", systemImage: DashboardSection.settings.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
                .padding(.top, 4)
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
                        refreshID: refreshCommandsID
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
