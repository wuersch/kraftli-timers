//
//  ContentView.swift
//  Kraftli Timers Watch App
//
//  Created by Michael Würsch on 18.01.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            WatchPresetListView()
        }
    }
}

#Preview {
    ContentView()
}
