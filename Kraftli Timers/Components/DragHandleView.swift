//
//  DragHandleView.swift
//  Kraftli Timers
//
//  Extracted from timer views for reuse.
//

import SwiftUI

/// A capsule-shaped drag handle that appears at the top of dismissible views.
/// Changes color when actively dragging and moves with the drag offset.
struct DragHandleView: View {
    /// Whether the handle is currently being dragged
    let isActive: Bool
    /// Current vertical drag offset in points
    let dragOffset: CGFloat

    var body: some View {
        VStack {
            Capsule()
                .fill(isActive ? Color.primary : Color.gray.opacity(0.25))
                .frame(width: 32, height: 4)
                .padding(.top, 12)
            Spacer()
        }
        .offset(y: dragOffset * 0.5)
        .opacity(1.0 - (dragOffset / 700.0))
        .allowsHitTesting(false)
    }
}

#Preview("Inactive") {
    ZStack {
        Color.black.ignoresSafeArea()
        DragHandleView(isActive: false, dragOffset: 0)
    }
}

#Preview("Active") {
    ZStack {
        Color.black.ignoresSafeArea()
        DragHandleView(isActive: true, dragOffset: 50)
    }
}
