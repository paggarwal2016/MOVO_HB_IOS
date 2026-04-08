//
//  ActionCard.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/03/26.
//

import SwiftUI

struct ActionCard: View {
    let title: String
    let description: String
    let buttonLabel: String
    var borderColor: Color = Color.indigo
    var isLoading: Bool = false
    var onButtonTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .lineSpacing(4)

            PrimaryButton(
                title: buttonLabel,
                backgroundColor: .gray.opacity(0.1),
                textColor: .black,
                isLoading: isLoading,
                action: onButtonTap
            )
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundColor(borderColor)
        )
        .padding(.horizontal, 20)
    }
}
