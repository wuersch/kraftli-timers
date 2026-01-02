//
//  ContentView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 17.12.2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                TimerPresetView()
            }.tabItem{
                Label("Timers", systemImage: "timer")
            }

            NavigationStack {
                ComingSoonView(title: "Settings", description: "Adjust settings and more", image: "gearshape")
            }.tabItem{
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
}

