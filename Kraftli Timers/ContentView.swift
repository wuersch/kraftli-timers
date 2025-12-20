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
                Label("EMOM", systemImage: "timer")
            }
            
            NavigationStack {
                AMRAPTimerView()
            }.tabItem{
                Label("AMRAP", systemImage: "figure.run")
            }
        }
    }
}

#Preview {
    ContentView()
}

