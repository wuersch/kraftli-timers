//
//  SwipeToDismissModifier.swift
//  Kraftli Timers
//
//  Extracted from timer views for reuse.
//

import SwiftUI

/// A view modifier that adds swipe-to-dismiss gesture behavior.
/// Applies drag offset, opacity fade, and handles dismiss logic.
struct SwipeToDismissModifier: ViewModifier {
    /// Current vertical drag offset
    @Binding var dragOffset: CGFloat
    /// Whether the drag handle is currently active
    @Binding var isHandleActive: Bool
    /// Called when the user completes a dismiss gesture
    let onDismiss: () -> Void
    /// When true, gestures are ignored
    let isDisabled: Bool

    func body(content: Content) -> some View {
        content
            .offset(y: dragOffset * 0.5)
            .opacity(1.0 - (dragOffset / 700.0))
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard !isDisabled else { return }
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                            if !isHandleActive {
                                withAnimation(.easeOut(duration: 0.1)) {
                                    isHandleActive = true
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        guard !isDisabled else { return }
                        let shouldDismiss = value.predictedEndTranslation.height > 200
                            || value.velocity.height > 500

                        if shouldDismiss {
                            withAnimation(.easeOut(duration: 0.25)) {
                                dragOffset = 800
                            }
                            onDismiss()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                                isHandleActive = false
                            }
                        }
                    }
            )
    }
}

extension View {
    /// Adds swipe-to-dismiss behavior to a view.
    ///
    /// - Parameters:
    ///   - dragOffset: Binding to the current drag offset
    ///   - isHandleActive: Binding to track if drag handle should highlight
    ///   - onDismiss: Closure called when dismiss gesture completes
    ///   - isDisabled: When true, gestures are ignored
    func swipeToDismiss(
        dragOffset: Binding<CGFloat>,
        isHandleActive: Binding<Bool>,
        onDismiss: @escaping () -> Void,
        isDisabled: Bool = false
    ) -> some View {
        modifier(SwipeToDismissModifier(
            dragOffset: dragOffset,
            isHandleActive: isHandleActive,
            onDismiss: onDismiss,
            isDisabled: isDisabled
        ))
    }
}
