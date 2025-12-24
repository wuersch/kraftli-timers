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
                Label("Emom Demo", systemImage: "timer")
            }
            
            NavigationStack {
                TimerPresetView()
            }.tabItem{
                Label("Timers", systemImage: "timer")
            }
            
            NavigationStack {
                ComingSoonView(title: "Programs", description: "Combine timers and workouts into programs", image: "flowchart")
            }.tabItem{
                Label("Programs", systemImage: "flowchart")
            }
            /*
            NavigationStack {
                ComingSoonView(title: "Goals", description: "Set your own training goals", image: "trophy")
            }.tabItem{
                Label("Goals", systemImage: "trophy")
            }
            */
            NavigationStack {
                ComingSoonView(title: "Stats", description: "See your progress over time", image: "chart.bar")
            }.tabItem{
                Label("Stats", systemImage: "chart.bar")
            }
            
            NavigationStack {
                ComingSoonView(title: "Settings", description: "Adjust settings and more", image: "gearshape")
            }.tabItem{
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

struct ComingSoonView: View {
    let title: String
    let description: String
    let image: String
    
    init(title: String, description: String, image: String) {
        self.title = title
        self.description = "Coming soon ⸱ \(description)"
        self.image = image
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // App-Icon-Style
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(width: 80, height: 80)
                
                Image(systemName: image)
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
            }
            .padding(.top, 30)
            
            Text(title)
                .font(.largeTitle.weight(.bold))
                .padding(.top, 4)
            
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color(uiColor: .systemFill).opacity(0.3), radius: 4, y: 2)
        )
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding()
        
        Spacer()
    }
}

#Preview {
    ContentView()
}

