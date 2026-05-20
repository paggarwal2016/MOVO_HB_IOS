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
    var onLogout: () -> Void

    private let theme = MovoTheme.color

    private var initial: String {
        userName.first.map(String.init)?.uppercased() ?? "?"
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center) {
            // Left — WELCOME + first name
            VStack(alignment: .leading, spacing: 3) {
                Text("WELCOME")
                    .textStyle(Typography.eyebrow)
                    .foregroundStyle(theme.textTertiary.color)

                Text(userName)
                    .textStyle(Typography.sectionTitle)
                    .foregroundStyle(theme.textPrimary.color)
                    .lineLimit(1)
            }

            Spacer()

            // Right — initial avatar (taps to logout)
            Button(action: onLogout) {
                ZStack {
                    Circle()
                        .fill(Color.movo.surface)
                        .overlay(Circle().strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
                        .frame(width: 44, height: 44)

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
