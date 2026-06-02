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
        case .success:              return Color.movo.success
        case .error:                return Color.movo.danger
        case .warning:              return Color.movo.warning
        case .info:                 return Color.movo.accent
        case .custom(_, let c, _):  return c
        }
    }

    var background: Color {
        switch self {
        case .custom(_, _, let bg): return bg
        default:                    return Color.movo.elevatedHigh
        }
    }
}

// MARK: - Toast Action

/// A labeled button rendered inside an actionable toast.
struct ToastAction {
    let label: String
    let action: () -> Void
}

// MARK: - Toast Model

struct ToastConfig {
    var message: String
    var style: ToastStyle = .success
    var position: ToastPosition = .bottom
    /// Auto-dismiss delay in seconds. `nil` keeps the toast on screen until dismissed.
    var duration: Double? = 2.5
    /// Optional title shown above the message in the rich (card) layout.
    var title: String? = nil
    /// Optional top image from the asset catalog (rich layout).
    var imageName: String? = nil
    /// Optional top SF Symbol (rich layout). Ignored when `imageName` is set.
    var imageSystemName: String? = nil
    /// When set the toast becomes tappable and shows a trailing chevron.
    var onTap: (() -> Void)? = nil
    /// Primary (emphasized) action button. When set the toast renders an action row.
    var primaryAction: ToastAction? = nil
    /// Secondary (plain) action button, shown alongside the primary action.
    var secondaryAction: ToastAction? = nil
    /// When true the screen behind the toast is dimmed and taps outside the toast
    /// are blocked (modal). Use for actionable toasts that require a choice.
    var dimsBackground: Bool = false

    /// True when the toast carries at least one labeled action button.
    var hasActions: Bool { primaryAction != nil || secondaryAction != nil }

    /// True when the toast should use the rich (card) layout: image / title / actions.
    var isRich: Bool { hasActions || title != nil || imageName != nil || imageSystemName != nil }
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
        // Actionable toasts stay until the user taps a button (or Cancel); a nil
        // duration also disables auto-dismiss. Otherwise dismiss after `duration`.
        guard !config.hasActions, let duration = config.duration else { return }
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
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
        // Modal toasts (actionable or dimmed) must capture all taps so their buttons
        // receive them; non-modal toasts let taps outside the capsule fall through.
        let isModal = config.hasActions || config.dimsBackground
        window.passesThroughTaps = !isModal
        // Enable interaction for tappable, actionable, or dimming toasts.
        window.isUserInteractionEnabled = config.onTap != nil || isModal

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
    /// When true, taps that resolve to the empty hosting view fall through to the app
    /// below. Set false for modal toasts so their buttons receive taps.
    var passesThroughTaps = true

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        guard passesThroughTaps else { return view }
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
        ZStack {
            // Dimming backdrop — captures taps so the toast stays modal.
            if config.dimsBackground {
                Color.black
                    .opacity(appeared ? 0.45 : 0)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.2), value: appeared)
                    .contentShape(Rectangle())
            }

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
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: appeared)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.xxl)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - ToastView

struct ToastView: View {
    let config: ToastConfig

    var body: some View {
        if config.isRich {
            cardToast
        } else {
            capsuleToast
        }
    }

    // MARK: - Capsule (message-only / single-tap) toast

    private var capsuleToast: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: config.style.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(config.style.iconColor)
            Text(config.message)
                .textStyle(Typography.bodyCompact)
                .foregroundColor(Color.movo.textPrimary)
                .multilineTextAlignment(.leading)
            if config.onTap != nil {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.movo.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.md)
        .background(config.style.background)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.movo.borderStrong, lineWidth: Stroke.hairline))
        .shadow(color: Color.movo.background.opacity(0.6), radius: 12, x: 0, y: 4)
        .contentShape(Capsule())
        .onTapGesture { config.onTap?() }
    }

    // MARK: - Rich card toast (image + title + description + buttons)

    private var cardToast: some View {
        VStack(spacing: Spacing.lg) {
            topImage

            VStack(spacing: Spacing.sm) {
                if let title = config.title {
                    Text(title)
                        .textStyle(Typography.cardHero)
                        .foregroundColor(Color.movo.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(config.message)
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if config.hasActions {
                HStack(spacing: Spacing.sm) {
                    if let secondary = config.secondaryAction {
                        actionButton(secondary, emphasized: false)
                    }
                    if let primary = config.primaryAction {
                        actionButton(primary, emphasized: true)
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        // Opaque elevated surface — cardSurface is intentionally 85% alpha, which
        // would let the dimmed backdrop show through a modal dialog.
        .background(Color.movo.elevatedHigh)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .strokeBorder(Color.movo.borderStrong, lineWidth: Stroke.hairline)
        )
        // Soft modal shadow — matches the app's alert dialogs (PinInputAlert / TextInputAlert).
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }

    @ViewBuilder
    private var topImage: some View {
        if let asset = config.imageName {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
        } else {
            // Rounded badge with a centered SF Symbol.
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(Color.movo.elevated)
                    .frame(width: 44, height: 44)
                Image(systemName: config.imageSystemName ?? config.style.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.movo.accent)
            }
        }
    }

    private func actionButton(_ action: ToastAction, emphasized: Bool) -> some View {
        Button {
            // Dismiss the toast first, then run the handler so any presented
            // sheet/navigation isn't blocked by the lingering toast window.
            Task { @MainActor in
                await ToastManager.shared.dismiss()
                action.action()
            }
        } label: {
            Text(action.label)
                .textStyle(Typography.buttonLarge)
                .foregroundColor(emphasized ? Color.movo.onAccent : Color.movo.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .fill(emphasized ? Color.movo.accent : Color.movo.elevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .strokeBorder(Color.movo.border,
                                      lineWidth: emphasized ? 0 : Stroke.hairline)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GlobalToastModifier (no-op — window handles presentation)

struct GlobalToastModifier: ViewModifier {
    func body(content: Content) -> some View { content }
}

extension View {
    func globalToast() -> some View { self.modifier(GlobalToastModifier()) }
}
