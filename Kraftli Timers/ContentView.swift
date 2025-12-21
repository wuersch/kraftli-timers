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
                EMOMTimerView()
            }.tabItem{
                Label("Timers", systemImage: "timer")
            }
            
            NavigationStack {
                Text("Coming soon")
            }.tabItem{
                Label("Programs", systemImage: "flowchart")
            }
            
            NavigationStack {
                Text("Coming soon")
            }.tabItem{
                Label("Goals", systemImage: "trophy")
            }
            
            NavigationStack {
                Text("Coming soon")
            }.tabItem{
                Label("Statistics", systemImage: "chart.bar")
            }
            
            NavigationStack {
                Text("Coming soon")
            }.tabItem{
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
}

