//
//  ConfirmationScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 08/05/26.
//

import SwiftUI
import Combine

// MARK: - Domain model

public struct SuccessConfirmation: Sendable, Identifiable {
    public var id: String { referenceCode }
    
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

    public let note: String?               // optional message/memo

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
                note: String? = nil,
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
        self.note = note
        self.arrivesText = arrivesText
        self.dateText = dateText
        self.referenceCode = referenceCode
    }
}

// MARK: - View Model

@MainActor
public final class SuccessConfirmationViewModel: ObservableObject {
    
    @Published public var success: SuccessConfirmation
    
    private let onDone: () -> Void
    
    public init(success: SuccessConfirmation, onDone: @escaping () -> Void) {
        self.success = success
        self.onDone = onDone
    }
    
    public func done() { onDone() }
    public func close() { onDone() }
}

// MARK: - Main View

public struct SuccessConfirmationView: View {
    
    @StateObject private var vm: SuccessConfirmationViewModel
    
    public init(viewModel: SuccessConfirmationViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            
            SuccessBackdrop()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    heroBlock
                        .padding(.top, Spacing.xxl)
                        .padding(.bottom, Spacing.sm)
                    
                    amountHero
                        .padding(.top, Spacing.xl + 6)
                        .padding(.bottom, Spacing.xxxl)
                    
                    summaryCard
                        .padding(.horizontal, Spacing.lg + 2)
                        .padding(.bottom, Spacing.lg)
                    
                    Spacer().frame(height: 120)
                }
            }
            
            bottomActions
            
        }
        .background(Color.movo.background)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Subviews
    
    private var heroBlock: some View {
        VStack(spacing: Spacing.md + 4) {
            CheckmarkHalo()
                .frame(width: 88, height: 88)
            
            Text(heroTitleText)
                .textStyle(Typography.heroTitle)
                .foregroundColor(Color.movo.textPrimary)
                .multilineTextAlignment(.center)
            
            heroSubtitle
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, Spacing.xxxl)
    }
    
    private var heroSubtitle: some View {
        let prefix: String
        switch vm.success.channel {
        case .external:         prefix = "Your money is on its way to "
        case .internalTransfer: prefix = "We've moved it to "
        case .peer:             prefix = "Your money is on its way to "
        }
        
        return (
            Text(prefix)
                .foregroundColor(Color.movo.textTertiary)
            + Text(vm.success.toAccountName)
                .foregroundColor(Color.movo.textPrimary)
                .fontWeight(.medium)
            + Text(".")
                .foregroundColor(Color.movo.textTertiary)
        )
        .textStyle(Typography.subtitle)
    }
    
    private var amountHero: some View {
        VStack(spacing: 10) {
            Text("AMOUNT SENT")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.0)
                .foregroundColor(Color.movo.textTertiary)
            
            amountValue
        }
        .frame(maxWidth: .infinity)
    }
    
    private var amountValue: some View {
        let parts = splitAmount(vm.success.amount)
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("$")
                .font(.system(size: 24, weight: .medium).monospacedDigit())
                .foregroundColor(Color.movo.textTertiary)
                .baselineOffset(20)
            Text(parts.whole)
                .font(.system(size: 56, weight: .bold).monospacedDigit())
                .foregroundColor(Color.movo.textPrimary)
                .tracking(-1.7)
            Text(".\(parts.fraction)")
                .font(.system(size: 24, weight: .medium).monospacedDigit())
                .foregroundColor(Color.movo.textTertiary)
                .baselineOffset(20)
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: 0) {
            summaryRow(label: "From",
                       value: vm.success.fromAccountName,
                       meta: vm.success.fromAccountMask)
            divider
            
            summaryRow(label: "To",
                       value: vm.success.toAccountName,
                       meta: vm.success.toAccountMask)
//            divider
//
//            summaryRow(label: "Arrives",
//                       value: vm.success.arrivesText,
//                       meta: nil)
            if let note = vm.success.note, !note.isEmpty {
                divider
                summaryRow(label: "Note", value: note, meta: nil)
            }
            divider

            summaryRow(label: "Date",
                       value: vm.success.dateText,
                       meta: nil)
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.xxl)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xxl)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
        )
    }
    
    private func summaryRow(label: String, value: String, meta: String?) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .textStyle(Typography.caption)
                .foregroundColor(Color.movo.textTertiary)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundColor(Color.movo.textPrimary)
                if let meta {
                    Text(meta)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.movo.textTertiary)
                }
            }
        }
        .padding(.horizontal, Spacing.lg + 2)
        .padding(.vertical, Spacing.md + 2)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.movo.border)
            .frame(height: Stroke.hairline)
    }
    
    private var bottomActions: some View {
        PrimaryButton(title: "Done", backgroundColor: Color.movo.accent, textColor: .black) {
            vm.done()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl + 8)
    }
    
    // MARK: - Helpers
    
    private var heroTitleText: String {
        switch vm.success.channel {
        case .external, .peer, .internalTransfer: return "Transfer complete"
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
    
    var body: some View {
        RadialGradient(
            colors: [
                Color.movo.accent.opacity(0.14),
                Color.movo.background
            ],
            center: UnitPoint(x: 0.5, y: 0.20),
            startRadius: 0,
            endRadius: 360
        )
        .ignoresSafeArea()
    }
}


// MARK: - Checkmark Halo

private struct CheckmarkHalo: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.movo.accent.opacity(0.15),
                              lineWidth: Stroke.hairline)
                .padding(-16)
            
            Circle()
                .fill(Color.movo.accentSoft)
                .padding(-8)
            
            Circle()
                .fill(Color.movo.accentTint)
                .overlay(
                    Circle()
                        .strokeBorder(Color.movo.accent, lineWidth: 1.5)
                )
            
            Image(systemName: "checkmark")
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(Color.movo.accent)
        }
        .shadow(color: Color.movo.accent.opacity(0.35), radius: 30, x: 0, y: 0)
    }
}
