//
//  SupportSection.swift
//  MovocashIOS
//

import SwiftUI

struct SupportSection: View {

    @State private var showCannotCallAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {

            // Eyebrow — marked as a header for AX navigation.
            Text("SUPPORT")
                .font(Typography.eyebrow.font)
                .foregroundStyle(Color.movo.textTertiary)
                .padding(.leading, Spacing.xs)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                headerRow

                Divider()
                    .background(Color.movo.border)
                    .padding(.horizontal, Spacing.lg)

                bodyText

                ctaButton
            }
            .background(Color.movo.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
            )
        }
        .alert("Call Support", isPresented: $showCannotCallAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Phone calls aren't available on this device. Please call \(AppConfig.customerCare).")
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(Color.movo.elevated)
                    .frame(width: 44, height: 44)
                Image(systemName: "phone")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.movo.accent)
            }
            // Purely decorative — title conveys the purpose.
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Call Support")
                    .font(Typography.body.font)
                    .foregroundStyle(Color.movo.textPrimary)
                Text("PIN setup & account help")
                    .font(Typography.subtitle.font)
                    .foregroundStyle(Color.movo.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.rowPaddingVertical)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Body Copy

    private var bodyText: some View {
        Text("To set up your PIN or get help with your card, give us a call. Have your card ready.")
            .font(Typography.subtitle.font)
            .foregroundStyle(Color.movo.textTertiary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button(action: dial) {
            Text(AppConfig.customerCare)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .buttonStyle(MovoPrimaryButtonStyle())
        // Explicit floor keeps the tap target at ≥ 50 pt for AX guidance.
        .frame(minHeight: 50)
        .accessibilityLabel("Call support at \(AppConfig.customerCare)")
        .accessibilityHint("Dials the MOVO support line")
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Action

    private func dial() {
        guard let url = URL(string: AppConfig.customerCareNumber),
              UIApplication.shared.canOpenURL(url) else {
            showCannotCallAlert = true
            return
        }
        UIApplication.shared.open(url)
    }
}
