//
//  LoopSettingsSheet.swift
//  Kraftli Timers
//
//  Rounds and rest of a loop in a session (UC-0013 extension 3a).
//

import SwiftUI

/// Sets a loop's rounds (2–20) and the rest after each round except the last
/// (none, or up to 10 minutes).
struct LoopSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let onDone: (_ rounds: Int, _ restSeconds: Int) -> Void

    @State private var rounds: Int
    @State private var restMinutes: Int
    @State private var restSecondsPart: Int

    private static let maximumRestMinutes = SessionLoop.maximumRestSeconds / 60

    init(loop: SessionLoop, onDone: @escaping (_ rounds: Int, _ restSeconds: Int) -> Void) {
        self.onDone = onDone
        _rounds = State(initialValue: loop.rounds)
        _restMinutes = State(initialValue: loop.restSeconds / 60)
        // The wheel offers steps of 5 seconds.
        _restSecondsPart = State(initialValue: loop.restSeconds % 60 / 5 * 5)
    }

    private var restSeconds: Int {
        min(restMinutes * 60 + restSecondsPart, SessionLoop.maximumRestSeconds)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rounds") {
                    Picker("Rounds", selection: $rounds) {
                        ForEach(SessionLoop.roundsRange, id: \.self) { rounds in
                            Text("\(rounds)×").tag(rounds)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 110)
                }

                Section {
                    HStack {
                        Picker("Minutes", selection: $restMinutes) {
                            ForEach(0...Self.maximumRestMinutes, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        Picker("Seconds", selection: $restSecondsPart) {
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { seconds in
                                Text("\(seconds) sec").tag(seconds)
                            }
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 110)
                } header: {
                    Text("Rest between rounds")
                } footer: {
                    Text(restSeconds == 0
                         ? "No rest: the next round follows right away."
                         : "After each round except the last.")
                }
            }
            .onChange(of: restMinutes) { _, minutes in
                // 10 minutes is the most: no seconds on top.
                if minutes == Self.maximumRestMinutes {
                    restSecondsPart = 0
                }
            }
            .onChange(of: restSecondsPart) { _, seconds in
                if restMinutes == Self.maximumRestMinutes, seconds != 0 {
                    restSecondsPart = 0
                }
            }
            .navigationTitle("Loop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onDone(rounds, restSeconds)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Done")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    LoopSettingsSheet(loop: SessionLoop(rounds: 3, restSeconds: 60)) { _, _ in }
}
