//
//  ShimmerModifier.swift
//  MovocashIOS
//
//  Created by Movo Developer on 30/03/26.
//

import SwiftUI

// MARK: - ShimmerModifier

struct ShimmerModifier: ViewModifier {
    @State private var shimmer = false

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.08), .clear],
                    startPoint: shimmer ? .topLeading : .bottomTrailing,
                    endPoint:   shimmer ? .bottomTrailing : .topLeading
                )
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false), value: shimmer)
            )
            .onAppear { shimmer = true }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
