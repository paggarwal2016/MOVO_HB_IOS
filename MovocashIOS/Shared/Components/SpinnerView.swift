//
//  SpinnerView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI

struct SpinnerConfiguration {
    var spinnerColor: Color = .white
    var spinnerBackgroundColor: Color = .white.opacity(0.15)
    var backgroundCornerRadius: CGFloat = 30
    var width: CGFloat = 50
    var height: CGFloat = 50
    var speed: Double = 1
}

struct SpinnerView: View {
    var configuration: SpinnerConfiguration = SpinnerConfiguration()
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                
                // Optional dim layer for better glass visibility
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                
                // Spinner Container
                ZStack {
                    configuration.spinnerBackgroundColor
                    
                    Circle()
                        .trim(from: 0.2, to: 1)
                        .stroke(
                            configuration.spinnerColor,
                            style: StrokeStyle(
                                lineWidth: 5,
                                lineCap: .round
                            )
                        )
                        .frame(width: configuration.width,
                               height: configuration.height)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            .linear(duration: configuration.speed)
                            .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
                .frame(width: 90, height: 90)
                .background(.ultraThinMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: configuration.backgroundCornerRadius,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: configuration.backgroundCornerRadius,
                        style: .continuous
                    )
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(radius: 20)
            }
            .frame(width: geometry.size.width,
                   height: geometry.size.height)
            .onAppear {
                isAnimating = true
            }
        }
    }
}
