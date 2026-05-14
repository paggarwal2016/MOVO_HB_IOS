//
//  TextInputAlertView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 16/03/26.
//

import SwiftUI

// MARK: - TextInputAlertConfig

struct TextInputAlertConfig {
    // Header
    var headerBackground: Color  = Color.movo.accent
    var titleColor: Color        = Color.movo.onAccent
    var messageColor: Color      = Color.movo.onAccent.opacity(0.8)
    var headerIcon: String?      = nil

    // Primary (Create) button
    var primaryColor: Color      = Color.movo.accent
    var primaryLabel: String     = "Create"

    // Secondary (Cancel) button
    var secondaryColor: Color    = Color.movo.textTertiary
    var secondaryLabel: String   = "Cancel"

    // Card
    var cornerRadius: CGFloat    = Radius.sheet
}

// MARK: - TextInputAlertView

struct TextInputAlertView: View {
    let title: String
    let message: String
    let placeholder: String
    var config: TextInputAlertConfig = .init()
    @Binding var text: String
    var onCreate: () -> Void
    var onCancel: () -> Void

    private var r: CGFloat { config.cornerRadius }
    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Header
                VStack(spacing: 6) {
                    if let icon = config.headerIcon {
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(config.titleColor)
                            .padding(.bottom, 2)
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(config.titleColor)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(config.messageColor)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .background(config.headerBackground)
                //top two corners only
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: r,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: r
                ))

                // MARK: TextField Body
                VStack(spacing: 16) {
                    TextField(placeholder, text: $text)
                        .foregroundStyle(Color.movo.textPrimary)
                        .tint(Color.movo.accent)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(Color.movo.elevatedHigh)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.sm)
                                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                                )
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .background(Color.movo.elevated)

                // MARK: Buttons
                Rectangle()
                    .fill(Color.movo.border)
                    .frame(height: Stroke.hairline)
                HStack(spacing: 0) {

                    // Cancel
                    Button(action: onCancel) {
                        Text(config.secondaryLabel)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(config.secondaryColor)
                    }

                    Rectangle()
                        .fill(Color.movo.border)
                        .frame(width: Stroke.hairline, height: 44)

                    // Create
                    Button {
                        guard !isEmpty else { return }
                        onCreate()
                    } label: {
                        Text(config.primaryLabel)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(isEmpty ? config.primaryColor.opacity(0.4) : config.primaryColor)
                    }
                }
                .background(Color.movo.elevated)
                // bottom two corners only
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: r,
                    bottomTrailingRadius: r,
                    topTrailingRadius: 0
                ))
            }
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 4)
            .padding(.horizontal, 20)
        }
    }
}
