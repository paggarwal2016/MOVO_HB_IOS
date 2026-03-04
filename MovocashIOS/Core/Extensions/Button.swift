//
//  Button.swift
//  MovocashIOS
//
//  Created by Vinu on 04/03/26.
//

import Foundation
import SwiftUI

struct PrimaryButton: View {
    
    let title: String
    var backgroundColor: Color = AppColors.primary
    var textColor: Color = .white
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                action()
            }
        }) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: textColor)
                        )
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                isEnabled
                ? backgroundColor
                : backgroundColor.opacity(0.4)
            )
            .cornerRadius(14)
            .shadow(
                color: isEnabled
                ? backgroundColor.opacity(0.25)
                : .clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(!isEnabled || isLoading)
    }
}



import SwiftUI

struct BackButton: View {
    
    var color: Color = .black
    var backgroundColor: Color = Color.gray.opacity(0.1)
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
        }
        .buttonStyle(.plain)
    }
}













struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppColors.primary)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct BorderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppColors.primary)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: 2))
            .foregroundColor(.blue)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
