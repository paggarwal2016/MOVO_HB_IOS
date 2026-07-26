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

            HStack(alignment: .center, spacing: 10) {
                Image("herringLogo").resizable().scaledToFit()
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("MOVOCASH")
                        .textStyle(Typography.sectionTitle)
                        .foregroundStyle(Color.movo.textPrimary)

                    Text("Powered by HyperBin\u{00AE}")
                        .textStyle(Typography.caption)
                        .foregroundColor(Color.movo.textSecondary)
                }
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
