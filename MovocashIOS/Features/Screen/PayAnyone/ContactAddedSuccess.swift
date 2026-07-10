//
//  ContactAddedSuccess.swift
//  MovocashIOS
//
//  Created by Movo Developer on 29/05/26.
//

import SwiftUI

/// Full-screen confirmation shown after a contact is successfully added.
/// Styled entirely from the design-config tokens (Color.movo / Spacing /
/// Radius / Stroke / Typography) so it re-skins with the rest of the app.
struct ContactAddedSuccess: View {

    /// Display name of the newly added contact.
    let name: String
    /// Formatted phone number (E.164 or pretty form).
    let phone: String
    /// Whether the contact is a MOVO member. Defaults to `false` — membership
    /// isn't known at add-time, so the badge stays hidden unless set.
    var isMovoMember: Bool = false

    var onQuickSend: () -> Void = {}
    var onMaybeLater: () -> Void = {}

    // MARK: - Derived display values

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        let value = String(letters).uppercased()
        return value.isEmpty ? "?" : value
    }

    private var firstName: String {
        String(name.split(separator: " ").first ?? Substring(name))
    }

    // MARK: - Body

    var body: some View {
        ZStack {

            SuccessBackdrop()

            VStack(spacing: 0) {

                Spacer().frame(height: Spacing.huge + Spacing.xxl) // 64pt

                // MARK: - Success Icon

                CheckmarkHalo()
                    .frame(width: 88, height: 88)

                Spacer().frame(height: Spacing.xxl)

                // MARK: - Eyebrow pill

                Text("CONTACT ADDED")
                    .textStyle(Typography.eyebrow)
                    .foregroundColor(Color.movo.accent)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.movo.accentTint)
                            .overlay(
                                Capsule().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                            )
                    )

                Spacer().frame(height: Spacing.xxl)

                // MARK: - Contact Card

                HStack(spacing: Spacing.lg) {

                    // Avatar tile
                    ZStack {
                        Circle()
                            .fill(Color.movo.accentTint)
                            .overlay(Circle().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline))
                            .frame(width: 44, height: 44)

                        Text(initials)
                            .textStyle(Typography.cardTitle)
                            .foregroundColor(Color.movo.accent)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {

                        Text(name)
                            .textStyle(Typography.cardTitle)
                            .foregroundColor(Color.movo.textPrimary)

                        Text(phone)
                            .textStyle(Typography.subtitle)
                            .foregroundColor(Color.movo.textTertiary)

                        if isMovoMember {
                            StatusPill("Movo member", variant: .success, icon: "checkmark.seal.fill", style: Typography.pill)
                                .padding(.top, Spacing.xxs)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sheet)
                        .fill(Color.movo.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sheet)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
                .padding(.horizontal, Spacing.xxl)

                Spacer().frame(height: Spacing.xxl)

                // MARK: - Description

                (
                    Text("\(firstName) was added to your contacts. Would you like to ")
                        .foregroundColor(Color.movo.textTertiary)
                    + Text("send to spend")
                        .foregroundColor(Color.movo.textPrimary)
                        .bold()
                    + Text("?")
                        .foregroundColor(Color.movo.textTertiary)
                )
                .textStyle(Typography.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.huge)

                Spacer()

                // MARK: - CTAs

                VStack(spacing: Spacing.xs) {

                    Button(action: onQuickSend) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "paperplane.fill")
                            Text("Quick send")
                        }
                    }
                    .buttonStyle(MovoPrimaryButtonStyle())

                    Button("Maybe later", action: onMaybeLater)
                        .buttonStyle(MovoTextButtonStyle())
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xxxl)
            }
        }
    }
    
    private struct SuccessBackdrop: View {
        
        var body: some View {
            RadialGradient(
                colors: [
                    Color.movo.accent.opacity(0.14),
                    Color.movo.background
                ],
                center: UnitPoint(x: 0.5, y: 0.20),
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }

}
