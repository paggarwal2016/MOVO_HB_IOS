//
//  ActionCard.swift
//  MovocashIOS
//
//  Created by Vinu on 25/03/26.
//

import SwiftUI

struct ActionCard: View {
    let title: String
    let description: String
    let buttonLabel: String
    var borderColor: Color = Color.indigo
    var onButtonTap: () -> Void = {}
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineSpacing(4)
            
            Button(action: onButtonTap) {
                Text(buttonLabel)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: 1))
            }
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

