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
    var onDismiss: (() -> Void)? = nil

    @SwiftUI.Environment(\.openURL) private var openURL
    @State private var isChecking = false
    @State private var appear = false

    private static let fallbackStoreURL = URL(string: "https://apps.apple.com/app/id1538828856")
    private static let defaultUpdateMessage =
        "A new version of MovoCash is available. Please update to continue."

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

                Text(title.capitalized)
                    .textStyle(Typography.sectionTitle)
                    .foregroundColor(tint)
                    .padding(.bottom, Spacing.sm)

                Text(message)
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.sm)

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
        case .forceUpdate(let type, _, _, let storeURL):
            Button {
                AnalyticsManager.shared.log(
                    AnalyticsEvent.appUpdateCtaTapped,
                    params: [AnalyticsParam.updateType: type.rawValue]
                )
                // Fall back to the app's known store URL so the button always has a
                // destination — a force-update must never be a dead-end.
                if let url = storeURL ?? Self.fallbackStoreURL { openURL(url) }
            } label: {
                Text("Update Now")
            }
            .buttonStyle(MovoPrimaryButtonStyle())

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

        case .optionalUpdate(let type, _, _, let storeURL):
            VStack(spacing: Spacing.md) {
                Button {
                    AnalyticsManager.shared.log(
                        AnalyticsEvent.appUpdateCtaTapped,
                        params: [AnalyticsParam.updateType: type.rawValue]
                    )
                    if let url = storeURL ?? Self.fallbackStoreURL { openURL(url) }
                } label: {
                    Text("Update Now")
                }
                .buttonStyle(MovoPrimaryButtonStyle())

                Button {
                    onDismiss?()
                } label: {
                    Text("Not Now")
                }
                .buttonStyle(OutlineButtonStyle())
            }

        case .upToDate:
            EmptyView()
        }
    }

    // MARK: - Severity-driven content

    /// Accent hue per severity: maintenance → warning; update → brand accent.
    private var tint: Color {
        switch outcome {
        case .maintenance:               return Color.movo.warning
        case .forceUpdate:               return Color.movo.accent
        case .optionalUpdate, .upToDate: return Color.movo.accent
        }
    }

    private var iconName: String {
        switch outcome {
        case .maintenance:               return "wrench.and.screwdriver.fill"
        case .forceUpdate:               return "arrow.down.circle.fill"
        case .optionalUpdate, .upToDate: return "arrow.down.circle.fill"
        }
    }

    private var eyebrow: String {
        switch outcome {
        case .maintenance:               return "SCHEDULED MAINTENANCE"
        case .forceUpdate:               return "UPDATE REQUIRED"
        case .optionalUpdate, .upToDate: return "UPDATE AVAILABLE"
        }
    }

    private var title: String {
        switch outcome {
        // Prefer the server's `updateTitle`; fall back to sane defaults when empty.
        case .maintenance(let title, _):          return title.isEmpty ? "We'll be right back" : title
        case .forceUpdate(_, let title, _, _):    return title.isEmpty ? "Time to update MovoCash" : title
        case .optionalUpdate(_, let title, _, _): return title.isEmpty ? "Update available" : title
        case .upToDate:                           return "Update available"
        }
    }

    private var message: String {
        switch outcome {
        // maintenance is already defaulted upstream in AppConfigService; force/optional
        // fall back here so the screen never renders with an empty body.
        case .forceUpdate(_, _, let message, _):    return message.isEmpty ? Self.defaultUpdateMessage : message
        case .maintenance(_, let message):          return message
        case .optionalUpdate(_, _, let message, _): return message.isEmpty ? Self.defaultUpdateMessage : message
        case .upToDate:                          return ""
        }
    }
}
