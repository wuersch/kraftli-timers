//
//  CardListStyleModifier.swift
//  Kraftli Timers
//
//  Applies plain list styling with hidden scroll background for card-based lists.
//

import SwiftUI

/// Applies plain list styling with hidden scroll background for card-based lists.
struct CardListStyleModifier: ViewModifier {
    let isEmpty: Bool

    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(isEmpty)
            .background(Color(UIColor.systemBackground))
    }
}

extension View {
    /// Styles a list for card-based content with optional scroll disable when empty.
    func cardListStyle(isEmpty: Bool = false) -> some View {
        modifier(CardListStyleModifier(isEmpty: isEmpty))
    }
}
