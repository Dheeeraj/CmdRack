//
//  ContentView.swift
//  CmdRack
//
//  Created by Dheeraj Rao on 09/02/26.
//

import SwiftUI

struct ContentView: View {
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CmdRack")
                .font(.headline)

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .frame(width: 340)
    }
}

#Preview {
    ContentView()
}
