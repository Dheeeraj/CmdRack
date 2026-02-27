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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CmdRack")
                .font(.headline)

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)

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

