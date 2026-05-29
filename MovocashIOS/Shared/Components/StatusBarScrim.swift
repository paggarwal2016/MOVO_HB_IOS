//
//  StatusBarScrim.swift
//  MovocashIOS
//
//  Permanent status-bar material scrim. Always visible, sized exactly
//  to the top safe area. Apply once in any ZStack above the scrollable
//  content to ensure the time and battery indicators remain readable
//  against scrolling content underneath.
//
//  Usage
//  ──────
//  In your view's ZStack(alignment: .top), add:
//      StatusBarScrim()
//  above the ScrollView/main content, below any loading overlays.
//

import SwiftUI

/// Translucent gradient scrim covering the top safe area. Fades from
/// near-opaque `Color.movo.background` at the top edge to fully clear
/// at the bottom of the status bar zone, allowing scrolling content
/// to peek through while keeping time/battery indicators readable.
struct StatusBarScrim: View {
    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                stops: [
                    .init(color: Color.movo.background.opacity(0.95), location: 0.0),
                    .init(color: Color.movo.background.opacity(0.75), location: 0.5),
                    .init(color: Color.movo.background.opacity(0.0),  location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: proxy.safeAreaInsets.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
    }
}
