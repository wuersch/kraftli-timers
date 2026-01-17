//
//  CardStyleModifier.swift
//  Kraftli Timers
//
//  Applies card styling with secondary background and rounded corners.
//

import SwiftUI

/// Applies card styling with secondary background and rounded corners.
struct CardStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    /// Applies card styling with secondary background and rounded corners.
    func cardStyle() -> some View {
        modifier(CardStyleModifier())
    }
}
