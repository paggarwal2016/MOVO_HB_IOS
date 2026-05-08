//
//  ConfirmationScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 08/05/26.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Domain model

public struct TransferSuccess: Sendable {

    public enum Channel: String, Sendable {
        case external          // Movo → bank (Wells Fargo, etc.)
        case internalTransfer  // Movo → Movo (own accounts)
        case peer              // Movo → person (Pay Anyone)
    }

    public let channel: Channel
    public let amount: Decimal
    public let currencyCode: String

    public let fromAccountName: String      // "Movo Primary"
    public let fromAccountMask: String?     // "••4521"

    public let toAccountName: String        // "Wells Fargo Checking" or "Maya Patel"
    public let toAccountMask: String?       // "••8900" or nil for peer

    public let arrivesText: String          // "By May 8, 2026" or "Instantly"
    public let dateText: String             // "May 5, 2026 · 9:41 AM"
    public let referenceCode: String        // "MV-20260505-9F2A"

    public init(channel: Channel,
                amount: Decimal,
                currencyCode: String = "USD",
                fromAccountName: String,
                fromAccountMask: String? = nil,
                toAccountName: String,
                toAccountMask: String? = nil,
                arrivesText: String,
                dateText: String,
                referenceCode: String) {
        self.channel = channel
        self.amount = amount
        self.currencyCode = currencyCode
        self.fromAccountName = fromAccountName
        self.fromAccountMask = fromAccountMask
        self.toAccountName = toAccountName
        self.toAccountMask = toAccountMask
        self.arrivesText = arrivesText
        self.dateText = dateText
        self.referenceCode = referenceCode
    }
}

// MARK: - View Model

@MainActor
public final class TransferSuccessViewModel: ObservableObject {

    @Published public var success: TransferSuccess
    @Published public var copiedToast: String?

    public init(success: TransferSuccess) {
        self.success = success
    }

    public func copyReference() {
        UIPasteboard.general.string = success.referenceCode
        showToast("Reference copied")
    }

    public func done()           { /* dismiss flow back to dashboard */ }
    public func viewReceipt()    { /* navigate to receipt detail */ }
    public func close()          { done() }

    private func showToast(_ message: String) {
        copiedToast = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            copiedToast = nil
        }
    }
}

// MARK: - Main View

public struct TransferSuccessView: View {

    @StateObject private var vm: TransferSuccessViewModel

    public init(viewModel: TransferSuccessViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {

            SuccessBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    navBar
                        .padding(.bottom, Spacing.sm)

                    heroBlock
                        .padding(.top, Spacing.xxl)
                        .padding(.bottom, Spacing.sm)

                    amountHero
                        .padding(.top, Spacing.xl + 6)
                        .padding(.bottom, Spacing.xxxl)

                    summaryCard
                        .padding(.horizontal, Spacing.lg + 2)
                        .padding(.bottom, Spacing.lg)

                    referenceStrip
                        .padding(.horizontal, Spacing.lg + 2)
                        .padding(.bottom, Spacing.lg)

                    Spacer().frame(height: 140) // CTA clearance
                }
            }

            bottomActions

            if let toast = vm.copiedToast {
                CopyToast(message: toast)
                    .padding(.bottom, 130)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.movo.background)
        .animation(.easeInOut(duration: DesignTokens.Motion.standard), value: vm.copiedToast)
    }

    // MARK: - Subviews

    private var navBar: some View {
        HStack {
            Spacer()
            CircularNavButton(systemName: "xmark") { vm.close() }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg - 2)
    }

    private var heroBlock: some View {
            VStack(spacing: Spacing.md + 4) {
                CheckmarkHalo()
                    .frame(width: 88, height: 88)

                Text(heroTitleText)
                    .textStyle(Typography.heroTitle)
                    .foregroundColor(scheme.textPrimary.color)
                    .multilineTextAlignment(.center)

                heroSubtitle(scheme: scheme)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 280)
            }
            .padding(.horizontal, Spacing.xxxl)
    }

    private func heroSubtitle(scheme: ColorScheme) -> some View {
        let prefix: String
        switch vm.success.channel {
        case .external:         prefix = "Your money is on its way to "
        case .internalTransfer: prefix = "We've moved it to "
        case .peer:             prefix = "Your money is on its way to "
        }

        return (
            Text(prefix)
                .foregroundColor(scheme.textTertiary.color)
            + Text(vm.success.toAccountName)
                .foregroundColor(scheme.textPrimary.color)
                .fontWeight(.medium)
            + Text(".")
                .foregroundColor(scheme.textTertiary.color)
        )
        .textStyle(Typography.subtitle)
    }

    private var amountHero: some View {
            VStack(spacing: 10) {
                Text("AMOUNT SENT")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.0)
                    .foregroundColor(scheme.textTertiary.color)

                amountValue(scheme: scheme)
            }
            .frame(maxWidth: .infinity)
    }

    private func amountValue(scheme: ColorScheme) -> some View {
        let parts = splitAmount(vm.success.amount)
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("$")
                .font(.system(size: 24, weight: .medium).monospacedDigit())
                .foregroundColor(scheme.textTertiary.color)
                .baselineOffset(20)
            Text(parts.whole)
                .font(.system(size: 56, weight: .bold).monospacedDigit())
                .foregroundColor(scheme.textPrimary.color)
                .tracking(-1.7)
            Text(".\(parts.fraction)")
                .font(.system(size: 24, weight: .medium).monospacedDigit())
                .foregroundColor(scheme.textTertiary.color)
                .baselineOffset(20)
        }
    }

    private var summaryCard: some View {
            VStack(spacing: 0) {
                summaryRow(label: "From",
                           value: vm.success.fromAccountName,
                           meta: vm.success.fromAccountMask,
                           scheme: scheme)
                divider(scheme: scheme)

                summaryRow(label: "To",
                           value: vm.success.toAccountName,
                           meta: vm.success.toAccountMask,
                           scheme: scheme)
                divider(scheme: scheme)

                summaryRow(label: "Arrives",
                           value: vm.success.arrivesText,
                           meta: nil,
                           scheme: scheme)
                divider(scheme: scheme)

                summaryRow(label: "Date",
                           value: vm.success.dateText,
                           meta: nil,
                           scheme: scheme)
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .fill(scheme.surface.color.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xxl)
                            .strokeBorder(scheme.border.color, lineWidth: Stroke.hairline)
                    )
            )
    }

    private func summaryRow(label: String,
                            value: String,
                            meta: String?,
                            scheme: ColorScheme) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .textStyle(Typography.caption)
                .foregroundColor(scheme.textTertiary.color)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundColor(scheme.textPrimary.color)
                if let meta = meta {
                    Text(meta)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(scheme.textTertiary.color)
                }
            }
        }
        .padding(.horizontal, Spacing.lg + 2)
        .padding(.vertical, Spacing.md + 2)
    }

    private func divider(scheme: ColorScheme) -> some View {
        Rectangle()
            .fill(scheme.border.color)
            .frame(height: Stroke.hairline)
    }

    private var referenceStrip: some View {
            HStack(spacing: Spacing.sm) {
                Text("REF · \(vm.success.referenceCode)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(scheme.textDisabled.color)

                Button(action: vm.copyReference) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(scheme.textTertiary.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.xs)
                                .fill(scheme.elevated.color.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.xs)
                                        .strokeBorder(scheme.border.color, lineWidth: Stroke.hairline)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy reference code")
            }
            .frame(maxWidth: .infinity)
    }

    private var bottomActions: some View {
            VStack(spacing: 0) {
                Button(action: vm.done) {
                    Text("Done")
                }
                .buttonStyle(MovoPrimaryButtonStyle())

                Button(action: vm.viewReceipt) {
                    Text("View receipt")
                }
                .buttonStyle(MovoTextButtonStyle())
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl + 8)
            .background(
                scheme.background.color.opacity(0.0)  // transparent — backdrop bleeds through
            )
    }

    // MARK: - Helpers

    private var heroTitleText: String {
        switch vm.success.channel {
        case .external, .peer:    return "Transfer sent"
        case .internalTransfer:   return "Transfer complete"
        }
    }

    private func splitAmount(_ value: Decimal) -> (whole: String, fraction: String) {
        let whole = NSDecimalNumber(decimal: value).intValue
        let fractionDecimal = (value - Decimal(whole)) * 100
        let cents = NSDecimalNumber(decimal: fractionDecimal).intValue
        return ("\(whole)", String(format: "%02d", abs(cents)))
    }
}

// MARK: - Backdrop with green bloom

private struct SuccessBackdrop: View {
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
      

        ZStack {
            if isDark {
                RadialGradient(
                    colors: [
                        scheme.accent.color.opacity(0.18),
                        Color(red: 0.04, green: 0.08, blue: 0.06).opacity(0.85),
                        scheme.background.color
                    ],
                    center: UnitPoint(x: 0.5, y: 0.22),
                    startRadius: 0,
                    endRadius: 380
                )
            } else {
                RadialGradient(
                    colors: [
                        scheme.accent.color.opacity(0.14),
                        scheme.background.color
                    ],
                    center: UnitPoint(x: 0.5, y: 0.20),
                    startRadius: 0,
                    endRadius: 360
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Checkmark halo

private struct CheckmarkHalo: View {
    var body: some View {
            ZStack {
                // Outermost faint ring
                Circle()
                    .strokeBorder(scheme.accent.color.opacity(0.15),
                                  lineWidth: Stroke.hairline)
                    .padding(-16)

                // Soft glow halo (8pt accent-soft)
                Circle()
                    .fill(scheme.accentSoft.color)
                    .padding(-8)

                // Tinted disc with accent border
                Circle()
                    .fill(scheme.accentTint.color)
                    .overlay(
                        Circle()
                            .strokeBorder(scheme.accent.color, lineWidth: 1.5)
                    )

                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(scheme.accent.color)
            }
            .shadow(color: scheme.accent.color.opacity(0.35), radius: 30, x: 0, y: 0)
    }
}

// MARK: - Copy toast

private struct CopyToast: View {
    let message: String
    var body: some View {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(scheme.accent.color)
                Text(message)
                    .textStyle(Typography.captionSmall)
                    .foregroundColor(scheme.textPrimary.color)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                Capsule()
                    .fill(scheme.elevated.color)
                    .overlay(
                        Capsule().strokeBorder(scheme.border.color, lineWidth: Stroke.hairline)
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }
}

// MARK: - Reusable bits

private struct CircularNavButton: View {
    let systemName: String
    let action: () -> Void
    var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(scheme.textSecondary.color)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(scheme.elevated.color.opacity(0.8))
                            .overlay(
                                Circle()
                                    .strokeBorder(scheme.border.color, lineWidth: Stroke.hairline)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
}

// MARK: - Preview

#Preview("External · Dark") {
    let success = TransferSuccess(
        channel: .external,
        amount: 1.00,
        fromAccountName: "Movo Primary",
        fromAccountMask: "••4521",
        toAccountName: "Wells Fargo Checking",
        toAccountMask: "••8900",
        arrivesText: "By May 8, 2026",
        dateText: "May 5, 2026 · 9:41 AM",
        referenceCode: "MV-20260505-9F2A"
    )
    return TransferSuccessView(viewModel: TransferSuccessViewModel(success: success))
        .preferredColorScheme(.dark)
}

#Preview("Peer · Dark") {
    let success = TransferSuccess(
        channel: .peer,
        amount: 24.50,
        fromAccountName: "Movo Primary",
        fromAccountMask: "••4521",
        toAccountName: "Maya Patel",
        toAccountMask: nil,
        arrivesText: "Instantly",
        dateText: "May 5, 2026 · 9:41 AM",
        referenceCode: "MV-20260505-A14F"
    )
    return TransferSuccessView(viewModel: TransferSuccessViewModel(success: success))
        .preferredColorScheme(.dark)
}

#Preview("External · Light") {
    let success = TransferSuccess(
        channel: .external,
        amount: 250.00,
        fromAccountName: "Movo Primary",
        fromAccountMask: "••4521",
        toAccountName: "Wells Fargo Checking",
        toAccountMask: "••8900",
        arrivesText: "By May 8, 2026",
        dateText: "May 5, 2026 · 9:41 AM",
        referenceCode: "MV-20260505-9F2A"
    )
    return TransferSuccessView(viewModel: TransferSuccessViewModel(success: success))
        .preferredColorScheme(.light)
}
