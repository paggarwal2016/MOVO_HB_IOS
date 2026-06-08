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
            
            
            VStack(alignment: .leading, spacing: 2) {
                Text("LET'S MOVO,")
                    .textStyle(Typography.eyebrow)
                    .foregroundStyle(Color.movo.accent)
                    .tracking(2.5)
                Text(userName)
                    .textStyle(Typography.sectionTitle)
                    .foregroundStyle(Color.movo.textPrimary)
            }

            Spacer()

            // Right — initial avatar (taps to open the Settings/profile tab)
            Button(action: onProfileTap) {
                ZStack {
                    Circle()
                        .fill(Color.movo.surface)
                        .overlay(Circle().strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
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
