//
//  CustomAlertView.swift
//  MovocashIOS
//
//  Design-system styled replacement for the native alert used by
//  `AlertManager.showCustom`. A centered, fintech-grade modal: dimmed backdrop,
//  a top badge (tick / Movo mark / error), a clear title/message hierarchy, a
//  full-width primary CTA, and an optional tertiary secondary action. Entrance is
//  animated by the presenter (`GlobalAlertModifier`) via a scale + opacity transition.
//

import SwiftUI

// MARK: - Top badge style

/// The image shown in the alert's top badge.
enum CustomAlertIcon {
    case success   // green tick
    case movo      // Movo "M" logomark
    case error     // red error mark
    case none      // no badge
}

// MARK: - CustomAlertConfig

struct CustomAlertConfig {
    var cardBackground: Color = Color.movo.elevated
    var cornerRadius: CGFloat = Radius.sheet
}

// MARK: - CustomAlertView

struct CustomAlertView: View {
    let title: String
    let message: String
    let primary: String
    var secondary: String? = nil
    /// Optional SF Symbol shown trailing the primary button label (e.g. "arrow.right").
    var primaryIcon: String? = nil
    /// Top badge image.
    var icon: CustomAlertIcon = .success
    var config: CustomAlertConfig = .init()
    var onPrimary: () -> Void
    var onSecondary: () -> Void

    var body: some View {
        ZStack {
            // Dimmed backdrop — captures touches so the content behind stays inert.
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            card
                .padding(.horizontal, 32)
        }
    }

    private var card: some View {
        VStack(spacing: 0) {

            iconBadge

            // Title
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.movo.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            // Message
            Text(message)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.movo.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 28)

            // Primary CTA
            Button(action: onPrimary) {
                HStack(spacing: 8) {
                    Text(primary)
                    if let primaryIcon {
                        Image(systemName: primaryIcon)
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .buttonStyle(MovoPrimaryButtonStyle())

            // Optional secondary (tertiary text button)
            if let secondary {
                Button(action: onSecondary) {
                    Text(secondary)
                }
                .buttonStyle(MovoTextButtonStyle())
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 22)
        .background(
            RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                .fill(config.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
        )
    }

    // MARK: - Badge

    @ViewBuilder
    private var iconBadge: some View {
        switch icon {
        case .success:
            badge(tint: Color.movo.accent, background: Color.movo.accentTint) {
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.movo.accent)
            }
        case .movo:
            badge(tint: Color.movo.accent, background: Color.movo.accentTint) {
                Image("herringLogo").resizable().scaledToFit()
                    .frame(width: 34, height: 34)
            }
        case .error:
            badge(tint: Color.movo.danger, background: Color.movo.dangerTint) {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.movo.danger)
            }
        case .none:
            EmptyView()
        }
    }

    private func badge<Content: View>(
        tint: Color,
        background: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Circle().fill(background)
            content()
        }
        .frame(width: 64, height: 64)
        .overlay(
            Circle().strokeBorder(tint.opacity(0.15), lineWidth: Stroke.thin)
        )
        .padding(.bottom, 18)
    }
}
