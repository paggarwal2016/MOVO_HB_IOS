//
//  CustomUIView.swift
//  MovocashIOS
//
//  Created by Vinu on 06/05/26.
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
                        Color(red: 0.78, green: 0.78, blue: 0.81),
                        Color(red: 0.54, green: 0.54, blue: 0.58),
                        Color(red: 0.35, green: 0.35, blue: 0.39)
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
                               with: .color(Color.movo.textSecondary.opacity(alpha)),
                               style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }
        }
    }
}


// MARK: - MLogo

struct MLogo: View {
    var body: some View {
        Canvas { context, size in
            let s = size.width / 100.0
            // Front M
            var front = Path()
            front.move(to: .init(x: 12 * s, y: 80 * s))
            front.addLine(to: .init(x: 12 * s, y: 22 * s))
            front.addLine(to: .init(x: 24 * s, y: 22 * s))
            front.addLine(to: .init(x: 38 * s, y: 48 * s))
            front.addLine(to: .init(x: 52 * s, y: 22 * s))
            front.addLine(to: .init(x: 64 * s, y: 22 * s))
            front.addLine(to: .init(x: 64 * s, y: 80 * s))
            front.addLine(to: .init(x: 54 * s, y: 80 * s))
            front.addLine(to: .init(x: 54 * s, y: 42 * s))
            front.addLine(to: .init(x: 42 * s, y: 64 * s))
            front.addLine(to: .init(x: 34 * s, y: 64 * s))
            front.addLine(to: .init(x: 22 * s, y: 42 * s))
            front.addLine(to: .init(x: 22 * s, y: 80 * s))
            front.closeSubpath()
            context.fill(front, with: .color(Color.movo.textPrimary))
            
            // Back M (offset, faded)
            var back = Path()
            back.move(to: .init(x: 36 * s, y: 80 * s))
            back.addLine(to: .init(x: 36 * s, y: 22 * s))
            back.addLine(to: .init(x: 48 * s, y: 22 * s))
            back.addLine(to: .init(x: 62 * s, y: 48 * s))
            back.addLine(to: .init(x: 76 * s, y: 22 * s))
            back.addLine(to: .init(x: 88 * s, y: 22 * s))
            back.addLine(to: .init(x: 88 * s, y: 80 * s))
            back.addLine(to: .init(x: 78 * s, y: 80 * s))
            back.addLine(to: .init(x: 78 * s, y: 42 * s))
            back.addLine(to: .init(x: 66 * s, y: 64 * s))
            back.addLine(to: .init(x: 58 * s, y: 64 * s))
            back.addLine(to: .init(x: 46 * s, y: 42 * s))
            back.addLine(to: .init(x: 46 * s, y: 80 * s))
            back.closeSubpath()
            context.fill(back, with: .color(Color.movo.textPrimary.opacity(0.55)))
        }
    }
}


// MARK: - MastercardMark

struct MastercardMark: View {
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.78, green: 0.78, blue: 0.81).opacity(0.55))
                    .frame(width: 18, height: 18)
                    .offset(x: -6)
                Circle()
                    .fill(Color(red: 0.59, green: 0.59, blue: 0.62).opacity(0.55))
                    .frame(width: 18, height: 18)
                    .offset(x: 6)
                    .blendMode(.screen)
            }
            .frame(width: 30, height: 18)
            
            VStack(spacing: 0) {
                Text("mastercard")
                    .font(.system(size: 7))
                    .tracking(0.4)
                    .foregroundColor(Color.movo.textSecondary)
                Text("platinum")
                    .font(.system(size: 6))
                    .foregroundColor(Color.movo.textTertiary)
            }
        }
    }
}
