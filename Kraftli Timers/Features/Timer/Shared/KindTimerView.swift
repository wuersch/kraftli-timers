//
//  KindTimerView.swift
//  Kraftli Timers
//
//  The timer screen of a kind, built from a timer's settings.
//

import SwiftUI

/// The timer for a kind (EMOM, AMRAP, For Time) with its model, from the workout's
/// `TimerConfig`.
///
/// The one place that knows which view and model belong to a kind and which defaults
/// apply. A single workout (`TimerRunnerView`) and a session's step (`SessionRunnerView`)
/// both use it, so the two can't drift apart.
///
/// The models built here are cheap; each timer view keeps only the first one in its
/// `@State`, so later re-evaluations of this body don't replace a running timer. Give
/// the view a new `.id` to start a fresh one.
struct KindTimerView: View {
    /// The workout, as built by `TimerConfig(kind:duration:targetReps:exerciseName:)`.
    let config: TimerConfig
    let feedbackProvider: any FeedbackProvider
    let link: TimerScreenLink

    @Environment(AppSettings.self) private var settings

    private var timerProvider: any TimerProvider {
        settings.smoothAnimationsEnabled ? DisplayLinkTimerProvider() : FoundationTimerProvider()
    }

    var body: some View {
        switch config.kind {
        case .emom:
            EMOMTimerView(
                timerModel: EMOMTimerModel(
                    totalDuration: config.totalDuration ?? 0,
                    intervalCount: config.intervalCount ?? 1,
                    timerProvider: timerProvider,
                    feedbackProvider: feedbackProvider
                ),
                config: config,
                showRepsInCenter: settings.emomShowRepsInCenter,
                link: link
            )
        case .amrap:
            AMRAPTimerView(
                timerModel: AMRAPTimerModel(
                    totalDuration: config.totalDuration ?? 0,
                    timerProvider: timerProvider,
                    feedbackProvider: feedbackProvider
                ),
                config: config,
                link: link
            )
        case .forTime:
            ForTimeTimerView(
                timerModel: ForTimeTimerModel(
                    targetReps: config.targetReps ?? TimerPreset.defaultForTimeReps,
                    timerProvider: timerProvider,
                    feedbackProvider: feedbackProvider
                ),
                config: config,
                link: link
            )
        }
    }
}
