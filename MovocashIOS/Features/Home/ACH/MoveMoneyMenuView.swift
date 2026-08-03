//
//  MoveMoneyMenuView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 09/04/26.
//

import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MoveMoneyMenuView: View {

    let onFundAccount: () -> Void
    let onInternalTransfer: () -> Void

    @State private var detentHeight: CGFloat = 160
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.securedDismiss) private var securedDismiss

    var body: some View {
        VStack(spacing: 0) {
            optionRow(
                icon: "building.columns",
                title: "Add Money",
                subtitle: "Deposit from a linked bank account",
                action: onFundAccount
            )

            Divider()
                .background(Color.movo.border)
                .padding(.horizontal, Spacing.xxl)

            optionRow(
                icon: "arrow.left.arrow.right",
                title: "Transfer Money",
                subtitle: "Move money between your accounts",
                action: onInternalTransfer,
                isLast: true
            )
            
            Button(action: { (securedDismiss ?? dismiss)() }) {
                Text("Cancel")
            }
            .buttonStyle(OutlineButtonStyle())
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, Spacing.sm)
        }
        .padding(.top, Spacing.xxl)
        .background(Color.movo.cardSurface.ignoresSafeArea())
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(ContentHeightKey.self) { height in
            detentHeight = height
        }
        .presentationDetents([.height(detentHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.movo.cardSurface)
    }

    private func optionRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void,
        isLast: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.button)
                        .fill(Color.movo.accentTint)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.button)
                                .strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color.movo.accent)
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .textStyle(Typography.cardTitle)
                        .foregroundStyle(Color.movo.textPrimary)
                    Text(subtitle)
                        .textStyle(Typography.subtitle)
                        .foregroundStyle(Color.movo.textSecondary)
                }
                Spacer()
                MovoChevron(.disclosure)
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.vertical, Spacing.lg)
            .padding(.bottom, isLast ? Spacing.sm : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
