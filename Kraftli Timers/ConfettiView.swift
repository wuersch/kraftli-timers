//
//  ConfettiView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 21.12.2025.
//

import SwiftUI

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiShape(type: piece.type)
                        .fill(piece.color)
                        .frame(width: piece.width, height: piece.height)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(piece.position)
                        .opacity(piece.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                generateConfetti(in: geometry.size)
            }
        }
    }

    private func generateConfetti(in size: CGSize) {
        let colors: [Color] = [
            .red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan, .mint,
            .indigo,
        ]

        // Extend start position above visible area
        let startY: CGFloat = -100
        let endY: CGFloat = size.height + 100

        for _ in 0..<120 {
            let startX = CGFloat.random(in: -50...size.width + 50)
            let endX = startX + CGFloat.random(in: -150...150)
            let type = ConfettiType.allCases.randomElement() ?? .rectangle

            let piece = ConfettiPiece(
                color: colors.randomElement() ?? .blue,
                width: type == .rectangle
                    ? CGFloat.random(in: 3...8) : CGFloat.random(in: 6...12),
                height: type == .rectangle
                    ? CGFloat.random(in: 12...20) : CGFloat.random(in: 6...12),
                position: CGPoint(x: startX, y: startY),
                finalPosition: CGPoint(x: endX, y: endY),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: 3...8),
                opacity: 1.0,
                type: type
            )
            confettiPieces.append(piece)
        }

        // Animate each piece individually
        for i in confettiPieces.indices {
            let delay = Double.random(in: 0...0.5)
            let duration = Double.random(in: 2.5...4.0)

            withAnimation(.easeOut(duration: duration).delay(delay)) {
                confettiPieces[i].position = confettiPieces[i].finalPosition
                confettiPieces[i].rotation +=
                    confettiPieces[i].rotationSpeed * 360
            }

            // Fade out near the end
            withAnimation(.easeIn(duration: 0.8).delay(delay + duration - 0.8))
            {
                confettiPieces[i].opacity = 0
            }
        }
    }
}

enum ConfettiType: CaseIterable {
    case rectangle
    case circle
    case triangle
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let width: CGFloat
    let height: CGFloat
    var position: CGPoint
    let finalPosition: CGPoint
    var rotation: Double
    let rotationSpeed: Double
    var opacity: Double
    let type: ConfettiType
}

struct ConfettiShape: Shape {
    let type: ConfettiType

    func path(in rect: CGRect) -> Path {
        Path { path in
            switch type {
            case .rectangle:
                path.addRect(rect)
            case .circle:
                path.addEllipse(in: rect)
            case .triangle:
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.closeSubpath()
            }
        }
    }
}
