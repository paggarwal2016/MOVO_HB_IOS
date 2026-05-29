//
//  CustomUIView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/05/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - CircularNavButton

struct CircularNavButton: View {
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.movo.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.movo.elevated)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - CardChip

struct CardChip: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(
                    colors: [
                        Color.movo.onCardArtwork,
                        Color.movo.cardArtworkMuted,
                        Color.movo.cardArtworkMuted.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            // Contact pads
            VStack(spacing: 11) {
                Rectangle()
                    .fill(Color.black.opacity(0.28))
                    .frame(height: 1.5)
                Rectangle()
                    .fill(Color.black.opacity(0.28))
                    .frame(height: 1.5)
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
        }
        .compositingGroup()
        .shadow(color: .white.opacity(0.3), radius: 0, x: 0, y: 0.5)
    }
}


// MARK: - Card Contact

struct ContactlessIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            for (radius, alpha) in [(CGFloat(0.18), 0.9), (CGFloat(0.32), 0.7), (CGFloat(0.46), 0.5)] {
                var path = Path()
                let cx = w * 0.25
                let cy = h * 0.5
                let r = w * radius
                path.addArc(center: .init(x: cx, y: cy), radius: r,
                            startAngle: .degrees(-50), endAngle: .degrees(50), clockwise: false)
                context.stroke(path,
                               with: .color(Color.movo.onCardArtwork.opacity(alpha)),
                               style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }
        }
    }
}


// MARK: - MLogo

//struct MLogo: View {
//    var body: some View {
//        Canvas { context, size in
//            let s = size.width / 100.0
//            // Front M
//            var front = Path()
//            front.move(to: .init(x: 12 * s, y: 80 * s))
//            front.addLine(to: .init(x: 12 * s, y: 22 * s))
//            front.addLine(to: .init(x: 24 * s, y: 22 * s))
//            front.addLine(to: .init(x: 38 * s, y: 48 * s))
//            front.addLine(to: .init(x: 52 * s, y: 22 * s))
//            front.addLine(to: .init(x: 64 * s, y: 22 * s))
//            front.addLine(to: .init(x: 64 * s, y: 80 * s))
//            front.addLine(to: .init(x: 54 * s, y: 80 * s))
//            front.addLine(to: .init(x: 54 * s, y: 42 * s))
//            front.addLine(to: .init(x: 42 * s, y: 64 * s))
//            front.addLine(to: .init(x: 34 * s, y: 64 * s))
//            front.addLine(to: .init(x: 22 * s, y: 42 * s))
//            front.addLine(to: .init(x: 22 * s, y: 80 * s))
//            front.closeSubpath()
//            context.fill(front, with: .color(Color.movo.textPrimary))
//            
//            // Back M (offset, faded)
//            var back = Path()
//            back.move(to: .init(x: 36 * s, y: 80 * s))
//            back.addLine(to: .init(x: 36 * s, y: 22 * s))
//            back.addLine(to: .init(x: 48 * s, y: 22 * s))
//            back.addLine(to: .init(x: 62 * s, y: 48 * s))
//            back.addLine(to: .init(x: 76 * s, y: 22 * s))
//            back.addLine(to: .init(x: 88 * s, y: 22 * s))
//            back.addLine(to: .init(x: 88 * s, y: 80 * s))
//            back.addLine(to: .init(x: 78 * s, y: 80 * s))
//            back.addLine(to: .init(x: 78 * s, y: 42 * s))
//            back.addLine(to: .init(x: 66 * s, y: 64 * s))
//            back.addLine(to: .init(x: 58 * s, y: 64 * s))
//            back.addLine(to: .init(x: 46 * s, y: 42 * s))
//            back.addLine(to: .init(x: 46 * s, y: 80 * s))
//            back.closeSubpath()
//            context.fill(back, with: .color(Color.movo.textPrimary.opacity(0.55)))
//        }
//    }
//}


// MARK: - MastercardMark

struct MastercardMark: View {
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(Color.movo.onCardArtwork.opacity(0.55))
                    .frame(width: 18, height: 18)
                    .offset(x: -6)
                Circle()
                    .fill(Color.movo.cardArtworkMuted.opacity(0.55))
                    .frame(width: 18, height: 18)
                    .offset(x: 6)
                    .blendMode(.screen)
            }
            .frame(width: 30, height: 18)

            VStack(spacing: 0) {
                Text("mastercard")
                    .font(.system(size: 7))
                    .tracking(0.4)
                    .foregroundColor(Color.movo.onCardArtwork)
                Text("platinum")
                    .font(.system(size: 6))
                    .foregroundColor(Color.movo.cardArtworkMuted)
            }
        }
    }
}




struct TabBarItem: View {
    let label: String
    let icon: String
    let active: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(active ? Color.movo.accent : Color.movo.textTertiary)
                Text(label)
                    .font(Typography.micro.font)
                    .foregroundColor(active ? Color.movo.accent : Color.movo.textTertiary)
                    .fontWeight(active ? .medium : .regular)
            }
            .frame(maxWidth: .infinity)
        }
    }
}



// MARK: - AddContact

// MARK: - Add Contact action card

struct AddContactActionCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
                HStack(spacing: Spacing.md + 2) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .fill(Color.movo.accentTint)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.lg)
                                    .strokeBorder(Color.movo.accentBorder,
                                                  lineWidth: Stroke.hairline)
                            )
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(Color.movo.accent)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add new contact")
                            .textStyle(Typography.cardTitle)
                            .foregroundColor(Color.movo.textPrimary)
                        Text("Save someone you pay often")
                            .textStyle(Typography.captionSmall)
                            .foregroundColor(Color.movo.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.movo.accent)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md + 2)
                .background(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .fill(Color.movo.surface.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.heroCard)
                                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}










struct AddContactCardView: View {
    
    @Binding var nickname: String
    @Binding var phoneNumber: String
    
    let isLoading: Bool
    let isFormValid: Bool
    
    let onAdd: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text("ADD NEW CONTACT")
                .font(Typography.eyebrow.font)
                .tracking(0.8)
                .foregroundColor(Color.movo.textTertiary)
            
            // Nickname
            TextField("", text: $nickname,
                      prompt: Text("Nickname (e.g., Mom, Roommate)")
                .foregroundColor(Color.movo.textDisabled))
            .font(Typography.subtitle.font)
            .foregroundColor(Color.movo.textPrimary)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.movo.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.movo.elevated, lineWidth: 0.5)
                    )
            )
            
            // Phone Field (WITH formatting logic)
            HStack(spacing: 10) {
                Text("+1")
                    .font(Typography.subtitle.font)
                    .foregroundColor(Color.movo.textTertiary)
                    .padding(.trailing, 10)
                    .overlay(
                        Rectangle()
                            .fill(Color.movo.elevated)
                            .frame(width: 0.5)
                            .padding(.vertical, 4),
                        alignment: .trailing
                    )
                
                TextField("", text: $phoneNumber,
                          prompt: Text("(555) 000-0000")
                    .foregroundColor(Color.movo.textDisabled))
                .font(Typography.subtitle.font)
                .foregroundColor(Color.movo.textPrimary)
                .keyboardType(.phonePad)
                .onChange(of: phoneNumber) { newValue in
                    let formatted = PhoneFormatter1.formatUS(newValue)
                    if phoneNumber != formatted {
                        phoneNumber = formatted
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.movo.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.movo.accentBorder, lineWidth: 0.5)
                    )
            )

            // Buttons
            HStack(spacing: 8) {
                
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(Typography.button.font)
                        .foregroundColor(Color.movo.textSecondary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.movo.elevated.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.movo.elevated, lineWidth: 0.5)
                                )
                        )
                }
                
                Button(action: onAdd) {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(Color.movo.background)
                                .scaleEffect(0.8)
                        } else {
                            Text("Quick Pay")
                                .font(Typography.button.font)
                                .foregroundColor(Color.movo.background)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isFormValid ? Color.movo.accent : Color.movo.accent.opacity(0.35))
                    )
                }
                .disabled(!isFormValid || isLoading)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.movo.elevated.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.movo.elevated, lineWidth: 0.5)
                )
        )
    }
}
