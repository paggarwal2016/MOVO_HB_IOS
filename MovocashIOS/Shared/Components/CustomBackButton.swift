//
//  CustomBackButton.swift
//  MovocashIOS
//
//  Created by Vinu on 18/06/26.
//

import SwiftUI

struct CustomBackButton: View {

    enum Size {
        case small, medium, large

        var frame: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 44
            case .large: return 52
            }
        }

        var icon: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 18
            case .large: return 22
            }
        }
    }

    enum Style {
        case filled
        case glass
        case outline
        case plain
    }

    enum ShapeStyle {
        case circle
        case roundedSquare
        case roundedRectangle
    }

    enum Direction {
        case left, right, up, down

        var degrees: Double {
            switch self {
            case .left: return 0
            case .right: return 180
            case .up: return -90
            case .down: return 90
            }
        }
    }

    var size: Size = .medium
    var style: Style = .filled
    var shape: ShapeStyle = .roundedSquare
    var direction: Direction = .left

    // Defaults pulled from the design token config so the component is
    // on-brand and adaptive (light/dark) out of the box. Call sites may
    // still override with any token color.
    var tint: Color = Color.movo.textPrimary
    var background: Color = Color.movo.background

    var action: () -> Void

    @State private var pressed = false

    var body: some View {

        Button {
            action()
        } label: {

            Image(systemName: "chevron.left")
                .font(.system(size: size.icon, weight: .bold))
                .foregroundStyle(tint)
                .rotationEffect(.degrees(direction.degrees))
                .frame(
                    width: shape == .roundedRectangle ? size.frame * 1.5 : size.frame,
                    height: size.frame
                )
                .background(backgroundView)
                .scaleEffect(pressed ? 0.92 : 1)
                .animation(.spring(response: 0.25), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    pressed = true
                }
                .onEnded { _ in
                    pressed = false
                }
        )
    }

    @ViewBuilder
    private var backgroundView: some View {

        switch style {

        case .plain:
            Color.clear

        case .filled:
            shapeView
                .fill(background)

        case .glass:
            shapeView
                .fill(.ultraThinMaterial)
                .overlay(
                    // Specular reflection — a silver sheen swept from the
                    // top-leading edge fading to clear, simulating light
                    // catching the glass. Built from the `silverTint` token.
                    LinearGradient(
                        colors: [
                            Color.movo.silverTint.opacity(0.45),
                            Color.movo.silverTint.opacity(0.10),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shapeView)
                    .allowsHitTesting(false)
                )
                .overlay(
                    // Adaptive silver hairline rim — design-system sheen token.
                    shapeView.stroke(Color.movo.silverTint.opacity(0.35),
                                     lineWidth: Stroke.hairline)
                )

        case .outline:
            shapeView
                .fill(Color.movo.surface)
                .overlay(
                    shapeView.stroke(Color.movo.border, lineWidth: Stroke.thin)
                )
        }
    }

    private var shapeView: AnyShape {

        switch shape {
        case .circle:
            return AnyShape(Circle())

        case .roundedSquare:
            return AnyShape(
                RoundedRectangle(cornerRadius: Radius.xl,
                                 style: .continuous)
            )

        case .roundedRectangle:
            return AnyShape(
                RoundedRectangle(cornerRadius: Radius.xxl,
                                 style: .continuous)
            )
        }
    }
}

struct AnyShape: Shape {

    private let pathBuilder: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}
