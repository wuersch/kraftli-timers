//
//  EMOMTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI

struct EMOMTimerView: View {
    @State
    private var timerModel: EMOMTimerModel
    
    init(timerModel: EMOMTimerModel = EMOMTimerModel(totalReps: 100, totalMinutes: 20)) {
        self.timerModel = timerModel
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Text(formatTime(timerModel.totalTimeRemaining))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 280, height: 280)
                
                Circle()
                    .trim(from: 0, to: timerModel.intervalProgress)
                    .stroke(
                        timerModel.isIntervalWarning ? Color.red : Color.blue,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 8) {
                    Text(formatTime(timerModel.intervalTimeRemaining))
                        .font(.system(size:56, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    
                    Text("\(timerModel.completedIntervals)/\(timerModel.totalIntervals)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if timerModel.isRunning {
                    timerModel.pause()
                } else {
                    timerModel.start()
                }
            }
                
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: {
                    if timerModel.isRunning {
                        timerModel.pause()
                    } else {
                        timerModel.start()
                    }
                }) {
                    Image(systemName: timerModel.isRunning ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 80, height: 80)
                        .background(timerModel.isRunning ? Color.orange : Color.green)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                
                Button(action: timerModel.reset) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title)
                        .frame(width: 80, height: 80)
                        .background(Color.gray.opacity(0.3))
                        .foregroundStyle(.primary)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 40)
        }
        .padding()
        .navigationTitle("EMOM Timer")
        .onDisappear {
            timerModel.pause()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
