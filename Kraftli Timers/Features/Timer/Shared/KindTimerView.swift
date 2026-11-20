//
//  KindTimerView.swift
//  Kraftli Timers
//
//  The timer screen of a kind, built from a timer's settings.
//

import SwiftUI

/// The timer for a kind (EMOM, AMRAP, For Time) with its model, from the settings a
/// preset or a session's step holds.
///
/// The one place that knows which view and model belong to a kind and which defaults
/// apply. A single workout (`TimerRunnerView`) and a session's step (`SessionRunnerView`)
/// both use it, so the two can't drift apart.
///
/// The models built here are cheap; each timer view keeps only the first one in its
/// `@State`, so later re-evaluations of this body don't replace a running timer. Give
/// the view a new `.id` to start a fresh one.
struct KindTimerView: View {
    let kind: TimerKind
    /// The length of an EMOM or AMRAP; unused for For Time.
    let duration: TimeInterval
    /// An EMOM's reps (one per interval) or a For Time's target.
    let targetReps: Int?
    let feedbackProvider: any FeedbackProvider
    let link: TimerScreenLink

    @Environment(AppSettings.self) private var settings

    private var timerProvider: any TimerProvider {
        settings.smoothAnimationsEnabled ? DisplayLinkTimerProvider() : FoundationTimerProvider()
    }

    var body: some View {
        switch kind {
        case .emom:
            EMOMTimerView(
                timerModel: EMOMTimerModel(
                    totalDuration: duration,
                    intervalCount: targetReps ?? 1,
                    timerProvider: timerProvider,
                    feedbackProvider: feedbackProvider
                ),
                showRepsInCenter: settings.emomShowRepsInCenter,
                link: link
            )
        case .amrap:
            AMRAPTimerView(
                timerModel: AMRAPTimerModel(
                    totalDuration: duration,
                    timerProvider: timerProvider,
                    feedbackProvider: feedbackProvider
                ),
                link: link
            )
        case .forTime:
            ForTimeTimerView(
                timerModel: ForTimeTimerModel(
                    targetReps: targetReps ?? TimerPreset.defaultForTimeReps,
                    timerProvider: timerProvider,
                    feedbackProvider: feedbackProvider
                ),
                link: link
            )
        }
    }
}
