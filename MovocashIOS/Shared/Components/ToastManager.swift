//
//  ToastManager.swift
//  MovocashIOS
//
//  Created by Vinu on 16/03/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Toast Position

enum ToastPosition {
    case top, center, bottom
}

// MARK: - Toast Style

enum ToastStyle {
    case success
    case error
    case warning
    case info
    case custom(icon: String, iconColor: Color, background: Color)
    
    var icon: String {
        switch self {
        case .success:              return "checkmark.circle.fill"
        case .error:                return "xmark.circle.fill"
        case .warning:              return "exclamationmark.triangle.fill"
        case .info:                 return "info.circle.fill"
        case .custom(let i, _, _):  return i
        }
    }
    
    var iconColor: Color {
        switch self {
        case .success:              return .green
        case .error:                return .red
        case .warning:              return .orange
        case .info:                 return .blue
        case .custom(_, let c, _):  return c
        }
    }
    
    var background: Color {
        switch self {
        case .custom(_, _, let bg): return bg
        default:                    return Color.black.opacity(0.82)
        }
    }
}

// MARK: - Toast Model

struct ToastConfig {
    var message: String
    var style: ToastStyle = .success
    var position: ToastPosition = .bottom
    var duration: Double = 2.5
}

// MARK: - ToastManager

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    @Published var current: ToastConfig?
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    func show(_ config: ToastConfig) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            current = config
        }
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(config.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await dismiss()
        }
    }
    
    // Convenience
    func show(_ message: String, style: ToastStyle = .success, position: ToastPosition = .bottom, duration: Double = 2.5) {
        show(ToastConfig(message: message, style: style, position: position, duration: duration))
    }
    
    func dismiss() async {
        withAnimation(.easeOut(duration: 0.25)) { current = nil }
    }
}

// MARK: - ToastView

struct ToastView: View {
    let config: ToastConfig
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: config.style.icon)
                .foregroundStyle(config.style.iconColor)
            Text(config.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(config.style.background)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - GlobalToastModifier

struct GlobalToastModifier: ViewModifier {
    @ObservedObject private var toast = ToastManager.shared
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let config = toast.current {
                toastOverlay(config: config)
                    .zIndex(999)
            }
        }
    }
    
    @ViewBuilder
    private func toastOverlay(config: ToastConfig) -> some View {
        VStack {
            if config.position == .top {
                ToastView(config: config)
                    .padding(.top, 56)
                    .transition(.move(edge: .top).combined(with: .opacity))
                Spacer()
            } else if config.position == .center {
                Spacer()
                ToastView(config: config)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                Spacer()
            } else { // .bottom
                Spacer()
                ToastView(config: config)
                    .padding(.bottom, 48)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: config.position)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

extension View {
    func globalToast() -> some View { self.modifier(GlobalToastModifier()) }
}
