//
//  MoveMoneyMenuView.swift
//  MovocashIOS
//
//  Created by Vinu on 09/04/26.
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
    let onTransferMoney: () -> Void
    let onInternalTransfer: () -> Void

    @State private var detentHeight: CGFloat = 160

    var body: some View {
        VStack(spacing: 0) {
            optionRow(
                icon: "building.columns",
                title: "Fund Account",
                subtitle: "Deposit from a linked bank account",
                action: onFundAccount
            )

            Divider().padding(.horizontal, 24)

            optionRow(
                icon: "person.2",
                title: "Pay Anyone",
                subtitle: "Send money to a contact",
                action: onTransferMoney
            )

            Divider().padding(.horizontal, 24)

            optionRow(
                icon: "arrow.left.arrow.right",
                title: "Transfer Money",
                subtitle: "Move money between your accounts",
                action: onInternalTransfer,
                bottomPadding: 8
            )
        }
        .padding(.top, 25)
        .background(Color.white)
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
    }

    private func optionRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void,
        bottomPadding: CGFloat = 16
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.softBlue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(Color.softBlue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, bottomPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
