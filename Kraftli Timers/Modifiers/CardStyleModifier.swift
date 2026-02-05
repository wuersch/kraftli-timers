//
//  CardStyleModifier.swift
//  Kraftli Timers
//
//  Applies card styling with secondary background and rounded corners.
//

import SwiftUI

/// Applies card styling with secondary background and rounded corners.
struct CardStyleModifier: ViewModifier {
    let padded: Bool

    func body(content: Content) -> some View {
        content
            .padding(padded ? .all : [])
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    /// Applies card styling with secondary background and rounded corners.
    ///
    /// - Parameter padded: When true (default), adds standard padding inside the card.
    ///   Set to false for containers with internal row padding (e.g., multi-row Settings sections).
    func cardStyle(padded: Bool = true) -> some View {
        modifier(CardStyleModifier(padded: padded))
    }
}
