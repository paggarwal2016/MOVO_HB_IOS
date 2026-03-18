//
//  ToastManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 16/03/26.
//

import Foundation
import SwiftUI
import Combine
import UIKit

// MARK: - Toast Position

enum ToastPosition {
    case top, center, bottom
}

// MARK: - Toast Style

enum ToastStyle {
    case success
    case error
    case warning
    case info
    case custom(icon: String, iconColor: Color, background: Color)

    var icon: String {
        switch self {
        case .success:              return "checkmark.circle.fill"
        case .error:                return "xmark.circle.fill"
        case .warning:              return "exclamationmark.triangle.fill"
        case .info:                 return "info.circle.fill"
        case .custom(let i, _, _):  return i
        }
    }

    var iconColor: Color {
        switch self {
        case .success:              return .green
        case .error:                return .red
        case .warning:              return .orange
        case .info:                 return .blue
        case .custom(_, let c, _):  return c
        }
    }

    var background: Color {
        switch self {
        case .custom(_, _, let bg): return bg
        default:                    return Color.black.opacity(0.82)
        }
    }
}

// MARK: - Toast Model

struct ToastConfig {
    var message: String
    var style: ToastStyle = .success
    var position: ToastPosition = .bottom
    var duration: Double = 2.5
}

// MARK: - ToastManager

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()

    private var dismissTask: Task<Void, Never>?
    private var toastWindow: UIWindow?

    private init() {}

    func show(_ config: ToastConfig) {
        dismissTask?.cancel()
        presentInWindow(config)
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(config.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await dismiss()
        }
    }

    func show(_ message: String, style: ToastStyle = .success, position: ToastPosition = .bottom, duration: Double = 2.5) {
        show(ToastConfig(message: message, style: style, position: position, duration: duration))
    }

    func dismiss() async {
        toastWindow?.isHidden = true
        toastWindow = nil
    }

    // MARK: - Private

    private func presentInWindow(_ config: ToastConfig) {
        // Tear down any existing toast first
        toastWindow?.isHidden = true
        toastWindow = nil

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first
        else { return }

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = false

        let hostingController = UIHostingController(
            rootView: ToastOverlayView(config: config)
        )
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController
        window.isHidden = false

        toastWindow = window
    }
}

// MARK: - PassthroughWindow
// Ensures touches fall through to the app beneath the toast

private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == rootViewController?.view ? nil : view
    }
}

// MARK: - ToastOverlayView (window-hosted)

private struct ToastOverlayView: View {
    let config: ToastConfig
    @State private var appeared = false

    private var entryOffset: CGFloat {
        appeared ? 0 : (config.position == .top ? -20 : 20)
    }

    var body: some View {
        VStack {
            if config.position == .top {
                ToastView(config: config)
                    .padding(.top, 56)
                Spacer()
            } else if config.position == .center {
                Spacer()
                ToastView(config: config)
                Spacer()
            } else {
                Spacer()
                ToastView(config: config)
                    .padding(.bottom, 48)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: entryOffset)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appeared)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .onAppear { appeared = true }
    }
}

// MARK: - ToastView

struct ToastView: View {
    let config: ToastConfig

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: config.style.icon)
                .foregroundStyle(config.style.iconColor)
            Text(config.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(config.style.background)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - GlobalToastModifier (no-op — window handles presentation)

struct GlobalToastModifier: ViewModifier {
    func body(content: Content) -> some View { content }
}

extension View {
    func globalToast() -> some View { self.modifier(GlobalToastModifier()) }
}
