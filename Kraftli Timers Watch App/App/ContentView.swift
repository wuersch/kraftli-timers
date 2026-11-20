//
//  ContentView.swift
//  Kraftli Timers Watch App
//
//  Created by Michael Würsch on 18.01.2026.
//

import SwiftUI

struct ContentView: View {
    /// Follows a training session run on the iPhone (ADR-0012).
    private let sessionFollower = WatchTimerRuntime.shared.sessionFollower

    var body: some View {
        // A ZStack layers its children: while the Watch holds a session's workout, the
        // session view lies over the timer list. The list stays in the hierarchy because
        // it presents each step's timer as a cover, which appears above both.
        ZStack {
            NavigationStack {
                WatchPresetListView()
            }
            .accessibilityHidden(sessionFollower.showsSession)

            if sessionFollower.showsSession {
                WatchSessionView(follower: sessionFollower)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sessionFollower.showsSession)
    }
}

#Preview {
    ContentView()
}
