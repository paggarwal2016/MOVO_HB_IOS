//
//  CustomHeaderView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import SwiftUI

struct CustomHeaderView: View {

    // MARK: - Properties

    var userName: String = ""
    var userImage: String = ""
    var onProfileTap: () -> Void

    private let theme = MovoTheme.color

    private var initial: String {
        userName.first.map(String.init)?.uppercased() ?? "?"
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center) {

            VStack(alignment: .leading, spacing: 4) {
                // Row 1: M symbol + MOVOCASH
                HStack(spacing: 10) {
                    MovoMVSymbol()
                        .frame(width: 22, height: 22)
                    Text("MOVOCASH")
                        .textStyle(Typography.sectionTitle)
                        .foregroundStyle(Color.movo.textPrimary)
                }

                // Row 2: WELCOME, {name} — indented to align with MOVOCASH text
                Text("WELCOME, \(userName)")
                    .font(Typography.eyebrow.font)
                    .tracking(2.5)
                    .foregroundColor(Color.movo.accent)
                    .padding(.leading, 32) // 22pt icon + 10pt spacing
            }

            Spacer()

            // Right — initial avatar (taps to open the Settings/profile tab)
            Button(action: onProfileTap) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.movo.surface)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.movo.accent, lineWidth: 1.5)
                        )

                    Text(initial)
                        .textStyle(Typography.cardTitle)
                        .foregroundStyle(theme.textPrimary.color)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
}
