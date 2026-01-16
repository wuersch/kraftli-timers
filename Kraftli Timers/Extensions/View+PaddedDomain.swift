//
//  View+PaddedDomain.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 16.01.2026.
//
import SwiftUI

extension View {
    @ViewBuilder
    func ifLet<T>(_ value: T?, transform: (Self, T) -> some View) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}
