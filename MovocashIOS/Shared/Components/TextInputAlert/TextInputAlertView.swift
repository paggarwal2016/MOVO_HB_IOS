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
    var headerBackground: Color  = Color.primary
    var titleColor: Color        = .white
    var messageColor: Color      = .white.opacity(0.85)
    var headerIcon: String?      = nil

    // Primary (Create) button
    var primaryColor: Color      = Color.primary
    var primaryLabel: String     = "Create"

    // Secondary (Cancel) button
    var secondaryColor: Color    = .gray
    var secondaryLabel: String   = "Cancel"

    // Card
    var cornerRadius: CGFloat    = 20
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
            Color.black.opacity(0.35).ignoresSafeArea()

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
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 20)
                .background(Color(.systemBackground))

                // MARK: Buttons
                Divider()
                HStack(spacing: 0) {

                    // Cancel
                    Button(action: onCancel) {
                        Text(config.secondaryLabel)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(config.secondaryColor)
                    }

                    Divider().frame(height: 44)

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
                .background(Color.secondary)
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
