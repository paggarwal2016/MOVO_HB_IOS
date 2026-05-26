//
//  OTPDigitBox.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/02/26.
//

import SwiftUI

struct OTPDigitBox: View {
    
    let digit: String
    let isActive: Bool
    let isFilled: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.movo.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(
                            isActive ? Color.movo.accent : Color.movo.border,
                            lineWidth: isActive ? Stroke.medium : Stroke.hairline
                        )
                )
                .frame(height: 55)

            Text(digit)
                .textStyle(Typography.heroTitle)
                .foregroundColor(Color.movo.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}
