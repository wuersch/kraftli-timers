//
//  ContentView.swift
//  Kraftli Timers Watch App
//
//  Created by Michael Würsch on 18.01.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var showEMOM = false
    @State private var showAMRAP = false

    var body: some View {
        List {
            Section {
                Button {
                    showEMOM = true
                } label: {
                    VStack(alignment: .leading) {
                        Text("Quick EMOM")
                            .font(.headline)
                        Text("1 min · 10 reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    showAMRAP = true
                } label: {
                    VStack(alignment: .leading) {
                        Text("Quick AMRAP")
                            .font(.headline)
                        Text("1 min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showEMOM) {
            WatchEMOMTimerView(
                totalDuration: 1 * 60,
                intervalDuration: 10
            )
        }
        .fullScreenCover(isPresented: $showAMRAP) {
            WatchAMRAPTimerView(totalDuration: 1 * 60)
        }
    }
}

#Preview {
    ContentView()
}
