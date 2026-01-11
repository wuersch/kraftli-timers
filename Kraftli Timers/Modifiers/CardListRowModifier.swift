//
//  CardListRowModifier.swift
//  Kraftli Timers
//
//  Applies card-style list row appearance for consistent list styling.
//

import SwiftUI

/// Applies card-style list row appearance: no separator, clear background, standard insets.
struct CardListRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

extension View {
    /// Styles a list row as a card with no separator and standard insets.
    func cardListRow() -> some View {
        modifier(CardListRowModifier())
    }
}
