//
//  SpinnerView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SpinnerConfiguration {
    var arcColor: Color        = Color.movo.accent
    var trackColor: Color      = Color.movo.accentSoft
    var backdropOpacity: Double = 0.60
    var cornerRadius: CGFloat  = Radius.xxl
    var arcWidth: CGFloat      = 40
    var arcHeight: CGFloat     = 40
    var strokeWidth: CGFloat   = 3.0
    var speed: Double          = 1.1

    static let `default` = SpinnerConfiguration()
}

struct SpinnerView: View {
    var configuration: SpinnerConfiguration = .default
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {

                // Backdrop — dims content beneath without obscuring context.
                // Must be black (not movo.background) so it darkens in both
                // light and dark modes; background is near-white in light mode.
                Color.black
                    .opacity(configuration.backdropOpacity)
                    .ignoresSafeArea()

                // Spinner container
                ZStack {

                    // Glass surface
                    Color.movo.elevated
                        .opacity(0.90)

                    // Track ring — guides the eye around the arc path
                    Circle()
                        .stroke(
                            configuration.trackColor,
                            style: StrokeStyle(
                                lineWidth: configuration.strokeWidth,
                                lineCap: .round
                            )
                        )
                        .frame(
                            width: configuration.arcWidth,
                            height: configuration.arcHeight
                        )

                    // Spinning accent arc
                    Circle()
                        .trim(from: 0.16, to: 1)
                        .stroke(
                            configuration.arcColor,
                            style: StrokeStyle(
                                lineWidth: configuration.strokeWidth,
                                lineCap: .round
                            )
                        )
                        .frame(
                            width: configuration.arcWidth,
                            height: configuration.arcHeight
                        )
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            .linear(duration: configuration.speed)
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                        .shadow(
                            color: configuration.arcColor.opacity(0.45),
                            radius: 8, x: 0, y: 0
                        )
                }
                .frame(width: 88, height: 88)
                .background(.ultraThinMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: configuration.cornerRadius,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: configuration.cornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                )
                .shadow(color: Color.movo.accentSoft, radius: 24, x: 0, y: 0)
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
            .onAppear { isAnimating = true }
        }
    }
}

// MARK: - Full-screen overlay (UIKit window level)
// Call SpinnerView.showFullScreen() / SpinnerView.hideFullScreen() from any screen
// to present the spinner above sheets, modals, and navigation layers.

#if canImport(UIKit)
extension SpinnerView {

    private static var overlayWindow: UIWindow?

    /// Presents a full-screen spinner above all UI layers (sheets, navigation, etc).
    static func showFullScreen(configuration: SpinnerConfiguration = .default) {
        guard overlayWindow == nil,
              let scene = UIApplication.shared.connectedScenes
                  .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = true
        // Apply the current appearance preference. Read fresh on every presentation
        // so a preference change between spinner shows is immediately reflected.
        // .unspecified lets the window follow the device setting live (System mode).
        window.overrideUserInterfaceStyle = Appearance.current.uiStyle

        let host = UIHostingController(rootView: SpinnerView(configuration: configuration))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false

        overlayWindow = window
    }

    /// Removes the full-screen spinner.
    static func hideFullScreen() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
    }
}
#endif
