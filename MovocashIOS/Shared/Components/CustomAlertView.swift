//
//  CustomAlertView.swift
//  MovocashIOS
//
//  Design-system styled replacement for the native alert used by
//  `AlertManager.showCustom`. A centered, fintech-grade modal: dimmed backdrop,
//  an icon badge, a clear title/message hierarchy, a full-width primary CTA, and
//  an optional tertiary secondary action. Entrance is animated by the presenter
//  (`GlobalAlertModifier`) via a scale + opacity transition.
//

import SwiftUI

// MARK: - CustomAlertConfig

struct CustomAlertConfig {
    /// Badge icon shown above the title. Defaults to a success check — the custom
    /// alert is used for confirmations ("Invite Sent", "You're on the waitlist").
    var icon: String?           = "checkmark.circle.fill"
    var iconTint: Color         = Color.movo.accent
    var iconBackground: Color   = Color.movo.accentTint
    var cardBackground: Color   = Color.movo.elevated
    var cornerRadius: CGFloat   = Radius.sheet
}

// MARK: - CustomAlertView

struct CustomAlertView: View {
    let title: String
    let message: String
    let primary: String
    var secondary: String? = nil
    /// Optional SF Symbol shown trailing the primary button label (e.g. "arrow.right").
    var primaryIcon: String? = nil
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

            // Icon badge
            if let icon = config.icon {
                ZStack {
                    Circle()
                        .fill(config.iconBackground)
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(config.iconTint)
                }
                .frame(width: 64, height: 64)
                .overlay(
                    Circle().strokeBorder(config.iconTint.opacity(0.15), lineWidth: Stroke.thin)
                )
                .padding(.bottom, 18)
            }

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
        .shadow(color: .black.opacity(0.35), radius: 30, x: 0, y: 14)
    }
}
