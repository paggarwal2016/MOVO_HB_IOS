//
//  ConfirmationBottomView.swift
//  MovocashIOS
//
//  Created by Vinu on 08/05/26.
//

import SwiftUI

struct ConfirmationBottomSheet: View {

    let channel: SuccessConfirmation.Channel
    let amount: String
    let fromName: String
    let fromMask: String?
    let toName: String
    let toMask: String?
    var note: String? = nil
    var isLoading: Bool = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var titleText: String {
        switch channel {
        case .external:         return "Review Transfer"
        case .internalTransfer: return "Review Transfer"
        case .peer:             return "Review Payment"
        }
    }

    private var arrivesText: String {
        switch channel {
        case .external:                 return "1–3 business days"
        case .internalTransfer, .peer:  return "Instantly"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text(titleText)
                .textStyle(Typography.heroTitle)
                .foregroundColor(Color.movo.textPrimary)
                .padding(.top, Spacing.lg)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.sm)

            amountDisplay
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)

            detailCard
                .padding(.horizontal, Spacing.lg)

            Spacer()

            HStack(spacing: Spacing.sm) {
                PrimaryButton(
                    title: "Cancel",
                    backgroundColor: Color.movo.surface,
                    textColor: Color.movo.textSecondary
                ) {
                    onCancel()
                }
                PrimaryButton(
                    title: "Confirm",
                    backgroundColor: Color.movo.accent,
                    textColor: Color.movo.onAccent,
                    isLoading: isLoading
                ) {
                    onConfirm()
                }
                .frame(height: 52)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: - Amount

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("$")
                .textStyle(Typography.sectionTitle)
                .foregroundColor(Color.movo.textSecondary)
                .baselineOffset(14)
            let parts = amount.split(separator: ".")
            Text(parts.first.map(String.init) ?? "0")
                .textStyle(Typography.displayLarge)
                .monospacedDigit()
                .foregroundColor(Color.movo.textPrimary)
            Text(".\(parts.count > 1 ? String(parts[1]) : "00")")
                .textStyle(Typography.sectionTitle)
                .monospacedDigit()
                .foregroundColor(Color.movo.textSecondary)
                .baselineOffset(14)
        }
    }

    // MARK: - Detail Card

    private var detailCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "FROM", title: fromName, subtitle: fromMask)
            rowDivider
            detailRow(label: "TO", title: toName, subtitle: toMask)
//            rowDivider
//            detailRow(label: "ARRIVES", title: arrivesText, subtitle: nil)
            if let note, !note.isEmpty {
                rowDivider
                detailRow(label: "NOTE", title: note, subtitle: nil)
            }
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

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.movo.border)
            .frame(height: Stroke.hairline)
            .padding(.horizontal, Spacing.lg)
    }

    private func detailRow(label: String, title: String, subtitle: String?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .textStyle(Typography.eyebrow)
                    .foregroundColor(Color.movo.textTertiary)
                Text(title)
                    .textStyle(Typography.cardTitle)
                    .foregroundColor(Color.movo.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .textStyle(Typography.subtitle)
                        .foregroundColor(Color.movo.textTertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }
}
