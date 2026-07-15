//
//  AppUpdateGateView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 15/07/26.
//

import SwiftUI

struct AppUpdateGateView: View {

    let outcome: AppUpdateOutcome
    let onRetry: () async -> Void

    @SwiftUI.Environment(\.openURL) private var openURL
    @State private var isChecking = false
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.movo.background
                .ignoresSafeArea()
            MovoBackground()
            AmbientGlowView(color: tint, opacity: 0.10)

            VStack(spacing: 0) {
                Spacer(minLength: Spacing.xl)

                heroMedallion
                    .padding(.bottom, Spacing.xxl)

                Text(eyebrow)
                    .textStyle(Typography.eyebrow)
                    .foregroundColor(tint)
                    .padding(.bottom, Spacing.sm)

                Text(title)
                    .textStyle(Typography.heroTitle)
                    .foregroundColor(Color.movo.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, Spacing.md)

                Text(message)
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.sm)

                if outcome.isSecurity {
                    reassuranceChip
                        .padding(.top, Spacing.xl)
                }

                Spacer(minLength: Spacing.xl)

                footer
            }
            .frame(maxWidth: 380)
            .padding(.horizontal, Spacing.xxl)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 12)
        }
        // Belt-and-suspenders: block any touch from reaching views behind the overlay.
        .contentShape(Rectangle())
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appear = true }
            AnalyticsManager.shared.trackScreen(AnalyticsScreen.appUpdate)
        }
    }

    // MARK: - Hero

    private var heroMedallion: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.10))
                .frame(width: 132, height: 132)
            Circle()
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)
                .frame(width: 132, height: 132)
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 92, height: 92)
            Image(systemName: iconName)
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(tint)
        }
    }

    /// Trust reassurance shown for security updates.
    private var reassuranceChip: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.movo.success)
            Text("Your money and personal data remain secure")
                .textStyle(Typography.caption)
                .foregroundColor(Color.movo.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(Color.movo.successTint)
        )
    }

    // MARK: - Footer (CTA + meta)

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: Spacing.md) {
            actionButton

            Text("You're currently on version \(AppInfo.version)")
                .textStyle(Typography.caption)
                .foregroundColor(Color.movo.textTertiary)
        }
        .padding(.bottom, Spacing.xl)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch outcome {
        case .forceUpdate(let type, _, let storeURL):
            Button {
                AnalyticsManager.shared.log(
                    AnalyticsEvent.appUpdateCtaTapped,
                    params: [AnalyticsParam.updateType: type.rawValue]
                )
                if let storeURL { openURL(storeURL) }
            } label: {
                Text("Update Now")
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .disabled(storeURL == nil)
            .opacity(storeURL == nil ? 0.45 : 1)

        case .maintenance:
            Button {
                guard !isChecking else { return }
                AnalyticsManager.shared.log(AnalyticsEvent.appMaintenanceRetry)
                Task {
                    isChecking = true
                    await onRetry()
                    isChecking = false
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    if isChecking {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.movo.onAccent)
                    }
                    Text(isChecking ? "Checking…" : "Try Again")
                }
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .disabled(isChecking)

        case .optionalUpdate, .upToDate:
            EmptyView()
        }
    }

    // MARK: - Severity-driven content

    /// Accent hue per severity: security → danger, maintenance → warning,
    /// mandatory/other → brand accent.
    private var tint: Color {
        switch outcome {
        case .maintenance:                 return Color.movo.warning
        case .forceUpdate(let type, _, _): return type == .security ? Color.movo.danger : Color.movo.accent
        case .optionalUpdate, .upToDate:   return Color.movo.accent
        }
    }

    private var iconName: String {
        switch outcome {
        case .maintenance:                 return "wrench.and.screwdriver.fill"
        case .forceUpdate(let type, _, _): return type == .security ? "lock.shield.fill" : "arrow.down.circle.fill"
        case .optionalUpdate, .upToDate:   return "arrow.down.circle.fill"
        }
    }

    private var eyebrow: String {
        switch outcome {
        case .maintenance:                 return "SCHEDULED MAINTENANCE"
        case .forceUpdate(let type, _, _): return type == .security ? "SECURITY UPDATE" : "UPDATE REQUIRED"
        case .optionalUpdate, .upToDate:   return "UPDATE AVAILABLE"
        }
    }

    private var title: String {
        switch outcome {
        case .maintenance:                 return "We'll be right back"
        case .forceUpdate(let type, _, _): return type == .security ? "Security update required" : "Time to update MovoCash"
        case .optionalUpdate, .upToDate:   return "Update available"
        }
    }

    private var message: String {
        switch outcome {
        case .forceUpdate(_, let message, _):    return message
        case .maintenance(let message):          return message
        case .optionalUpdate(_, let message, _): return message
        case .upToDate:                          return ""
        }
    }
}

// MARK: - Outcome helpers

private extension AppUpdateOutcome {
    /// True when this is a force update flagged as a security release.
    var isSecurity: Bool {
        if case .forceUpdate(.security, _, _) = self { return true }
        return false
    }
}
