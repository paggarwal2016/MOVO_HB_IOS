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
            
            MovoMVSymbol()
                .frame(width: 30, height: 30)
            
            
            // Left — WELCOME + first name
//            VStack(alignment: .leading, spacing: 3) {
//                Text("WELCOME")
//                    .textStyle(Typography.eyebrow)
//                    .foregroundStyle(theme.textTertiary.color)
//
//                Text(userName)
//                    .textStyle(Typography.sectionTitle)
//                    .foregroundStyle(theme.textPrimary.color)
//                    .lineLimit(1)
//            }

            Spacer()

            // Right — initial avatar (taps to open the Settings/profile tab)
            Button(action: onProfileTap) {
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
