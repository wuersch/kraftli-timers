//
//  ConfettiView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 21.12.2025.
//

import SwiftUI
import UIKit

// MARK: - Particle System Architecture
// Uses CAEmitterLayer for GPU-accelerated particle animations.
// The CPU only configures the emitter once; the GPU handles all
// per-frame particle state calculations, eliminating commit hitches.

struct ConfettiView: View {
    var body: some View {
        ConfettiEmitterRepresentable()
            .accessibilityHidden(true)
    }
}

// MARK: - UIViewRepresentable Bridge

private struct ConfettiEmitterRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> ConfettiEmitterContainerView {
        ConfettiEmitterContainerView()
    }

    func updateUIView(_ uiView: ConfettiEmitterContainerView, context: Context) {
        // No updates needed - animation is fire-and-forget
    }
}

// MARK: - Container View with CAEmitterLayer

private final class ConfettiEmitterContainerView: UIView {
    private var emitterLayer: CAEmitterLayer?
    private var cleanupWorkItem: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Create emitter on first valid layout
        guard bounds.width > 0, bounds.height > 0, emitterLayer == nil else {
            // Update existing emitter position if bounds change
            if let emitter = emitterLayer {
                emitter.frame = bounds
                emitter.emitterPosition = CGPoint(x: bounds.midX, y: -50)
                emitter.emitterSize = CGSize(width: bounds.width + 100, height: 1)
            }
            return
        }

        setupEmitter()
    }

    override func removeFromSuperview() {
        cleanup()
        super.removeFromSuperview()
    }

    private func setupEmitter() {
        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -50)
        emitter.emitterSize = CGSize(width: bounds.width + 100, height: 1)
        emitter.renderMode = .backToFront  // Solid colors, not additive blending

        // Create cells for all color/shape combinations
        emitter.emitterCells = createEmitterCells()

        layer.addSublayer(emitter)
        emitterLayer = emitter

        // Stop emitting after 0.5s burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak emitter] in
            emitter?.birthRate = 0
        }

        // Remove layer after all particles have fallen (5.5s total)
        let workItem = DispatchWorkItem { [weak self] in
            self?.cleanup()
        }
        cleanupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5, execute: workItem)
    }

    private func cleanup() {
        cleanupWorkItem?.cancel()
        cleanupWorkItem = nil
        emitterLayer?.removeFromSuperlayer()
        emitterLayer = nil
    }

    private func createEmitterCells() -> [CAEmitterCell] {
        let colors: [UIColor] = [
            .systemRed, .systemBlue, .systemGreen, .systemYellow, .systemOrange,
            .systemPurple, .systemPink, .systemCyan, .systemMint, .systemIndigo
        ]

        let shapes: [(image: CGImage, name: String)] = [
            (ShapeImages.rectangle, "rectangle"),
            (ShapeImages.circle, "circle"),
            (ShapeImages.triangle, "triangle")
        ]

        // 30 cells total: 10 colors × 3 shapes
        // birthRate per cell = 120 particles / 30 cells / 0.5s = 8
        var cells: [CAEmitterCell] = []

        for color in colors {
            for (image, _) in shapes {
                let cell = CAEmitterCell()
                cell.contents = image
                cell.color = color.cgColor

                // Birth rate: 8 particles per cell over 0.5s = ~120 total
                cell.birthRate = 8

                // Lifetime: 3.25s ± 0.75s gives 2.5-4.0s range
                cell.lifetime = 3.25
                cell.lifetimeRange = 0.75

                // Velocity: downward fall
                cell.velocity = 200
                cell.velocityRange = 80
                cell.emissionLongitude = .pi  // 180° with gravity creates falling effect
                cell.emissionRange = .pi / 4  // ±45° spread

                // Strong gravity to pull particles down
                cell.xAcceleration = 0
                cell.yAcceleration = 400

                // Rotation: 3-8 full rotations (spin is radians/sec)
                // Average lifetime ~3.25s, want ~5.5 rotations average
                // 5.5 * 2π / 3.25 ≈ 10.6 rad/s
                cell.spin = 10.6
                cell.spinRange = 5.0

                // Scale: small particles so shapes aren't too obvious
                cell.scale = 0.25
                cell.scaleRange = 0.08

                // Fade out toward end of lifetime
                // alphaSpeed of -0.25 means fully transparent after 4s
                cell.alphaSpeed = -0.25

                cells.append(cell)
            }
        }

        return cells
    }
}

// MARK: - Shape Image Generation

private enum ShapeImages {
    // White images that get tinted by CAEmitterCell.color

    static let rectangle: CGImage = {
        let size = CGSize(width: 8, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.cgImage!
    }()

    static let circle: CGImage = {
        let size = CGSize(width: 12, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return image.cgImage!
    }()

    static let triangle: CGImage = {
        let size = CGSize(width: 12, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: size.width / 2, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.close()
            path.fill()
        }
        return image.cgImage!
    }()
}
