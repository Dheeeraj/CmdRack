//
//  ContentView.swift
//  CmdRack
//
//  Created by Dheeraj Rao on 09/02/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var searchText = ""
    @State private var isSearchActive = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Search bar: placeholder mode vs active mode
            if isSearchActive {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Search commands...", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isSearchActive = false
                            searchText = ""
                            searchFocused = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .transition(.opacity)
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isSearchActive = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        searchFocused = true
                    }
                } label: {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                            Text("Search")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)

                        Spacer()

                        Text("Tab")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.tab, modifiers: [])
                .transition(.opacity)
            }

            RecentCommandsView()

            Button {
                openWindow(id: "manage")
            } label: {
                Label("Manage / Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 340)
    }
}

#Preview {
    ContentView()
}
