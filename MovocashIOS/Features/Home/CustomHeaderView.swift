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

            HStack(alignment: .center, spacing: 8) {
                Image("herringLogo").resizable().scaledToFit()
                    .frame(width: 40.8, height: 40.8)

                VStack(alignment: .leading, spacing: 0) {
                    Text("MOVOCASH")
                        .font(.system(size: 21, weight: .semibold))
                        .tracking(-0.4)
                        .foregroundStyle(Color.movo.textPrimary)

                    Text("Powered by HyperBin\u{00AE}")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.movo.textSecondary)
                        .offset(y: -2)
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
