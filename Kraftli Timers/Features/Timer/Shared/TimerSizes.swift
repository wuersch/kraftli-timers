//
//  TimerSizes.swift
//  Kraftli Timers
//
//  Responsive sizing calculations for timer views.
//  Provides consistent sizing across EMOM and AMRAP timers.
//

import SwiftUI

/// Holds calculated sizes for responsive timer layout.
///
/// Timer views use proportional sizing based on available screen space.
/// This struct centralizes the sizing calculations to ensure consistency.
///
/// ## Usage
/// ```swift
/// GeometryReader { geometry in
///     let sizes = TimerSizes.emom(for: geometry.size)
///     // Use sizes.primaryRing, sizes.primaryFont, etc.
/// }
/// ```
struct TimerSizes {
    // MARK: - Ring Sizes

    /// Primary ring diameter (inner ring for EMOM, single ring for AMRAP).
    let primaryRing: CGFloat

    /// Primary ring stroke width.
    let primaryLineWidth: CGFloat

    /// Secondary ring diameter (outer ring for EMOM, nil for AMRAP).
    let secondaryRing: CGFloat?

    /// Secondary ring stroke width (outer ring for EMOM, nil for AMRAP).
    let secondaryLineWidth: CGFloat?

    // MARK: - Font Sizes

    /// Primary center display font (interval time or round count).
    let primaryFont: CGFloat

    /// Total time display font.
    let totalFont: CGFloat

    /// Small label font (e.g., "INTERVAL", "TOTAL").
    let labelFont: CGFloat

    /// Pill badge font.
    let pillFont: CGFloat

    // MARK: - Layout

    /// Vertical spacing between ring section and total section.
    let spacing: CGFloat
}

// MARK: - Factory Methods

extension TimerSizes {
    /// Creates sizes for EMOM timer with dual rings.
    ///
    /// EMOM has an outer ring (overall progress) and inner ring (interval progress).
    /// Reference sizing based on iPhone 14 Pro width ≈ 393pt.
    ///
    /// - Parameter size: Available container size from GeometryReader.
    /// - Returns: Configured TimerSizes for EMOM layout.
    static func emom(for size: CGSize) -> TimerSizes {
        // Use height * 0.55 as vertical constraint (rings + total section need ~55% of height)
        let heightConstrained = size.height * 0.55
        let effectiveWidth = min(size.width, heightConstrained, 600)

        return TimerSizes(
            primaryRing: effectiveWidth * 0.71,       // 280/393 (inner ring)
            primaryLineWidth: effectiveWidth * 0.05,  // 20/393
            secondaryRing: effectiveWidth * 0.81,     // 320/393 (outer ring)
            secondaryLineWidth: effectiveWidth * 0.025, // 10/393
            primaryFont: effectiveWidth * 0.14,       // 56/393 (interval font)
            totalFont: effectiveWidth * 0.15,         // 60/393
            labelFont: effectiveWidth * 0.038,        // ~15/393
            pillFont: effectiveWidth * 0.038,         // ~15/393
            spacing: effectiveWidth * 0.10            // 40/393
        )
    }

    /// Creates sizes for AMRAP timer with single ring.
    ///
    /// AMRAP has a single progress ring showing time remaining.
    /// Reference sizing based on iPhone 14 Pro width ≈ 393pt.
    ///
    /// - Parameter size: Available container size from GeometryReader.
    /// - Returns: Configured TimerSizes for AMRAP layout.
    static func amrap(for size: CGSize) -> TimerSizes {
        let heightConstrained = size.height * 0.55
        let effectiveWidth = min(size.width, heightConstrained, 600)

        return TimerSizes(
            primaryRing: effectiveWidth * 0.75,       // Single ring
            primaryLineWidth: effectiveWidth * 0.05,
            secondaryRing: nil,                       // AMRAP has no second ring
            secondaryLineWidth: nil,
            primaryFont: effectiveWidth * 0.20,       // Larger for round count
            totalFont: effectiveWidth * 0.15,
            labelFont: effectiveWidth * 0.038,
            pillFont: effectiveWidth * 0.038,
            spacing: effectiveWidth * 0.10
        )
    }
}
