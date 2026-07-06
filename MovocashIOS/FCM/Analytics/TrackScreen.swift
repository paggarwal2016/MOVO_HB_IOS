//
//  TrackScreen.swift
//  MovocashIOS
//
//  Reusable screen-view tracking for SwiftUI.
//

import SwiftUI

/// Logs a Firebase `screen_view` when the view first appears. Screen tracking is a
/// view-layer concern, so this uses the shared analytics instance rather than
/// requiring every screen to have `AnalyticsTracking` injected.
private struct TrackScreenModifier: ViewModifier {
    let name: String
    @State private var logged = false

    func body(content: Content) -> some View {
        content.onAppear {
            // Guard against SwiftUI firing onAppear more than once for the same
            // view instance (parent re-renders) so counts aren't inflated.
            guard !logged else { return }
            logged = true
            AnalyticsManager.shared.trackScreen(name)
        }
    }
}

extension View {
    /// Tracks a `screen_view` event the first time this view appears.
    func trackScreen(_ name: String) -> some View {
        modifier(TrackScreenModifier(name: name))
    }
}
