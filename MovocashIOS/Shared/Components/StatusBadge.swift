//
//  StatusBadge.swift
//  MovocashIOS
//
//  Created by Movo Developer on 18/03/26.
//

import Foundation
import SwiftUI


// MARK: - BadgeStatus

enum BadgeStatus {
    
    // MARK: Card
    case cardPrimary
    case cardActive
    case cardInactive
    case cardFrozen
    case cardPending
    case cardClosed
    case cardView
    
    // MARK: Account
    case emailVerified
    case emailUnverified
    case smsVerified
    case smsUnverified
    case twoFactorEnabled
    case twoFactorDisabled
    
    // MARK: - Label
    
    var label: String {
        switch self {
        case .cardPrimary:       return "Primary"
        case .cardActive:        return "Active"
        case .cardInactive:      return "Inactive"
        case .cardFrozen:        return "Frozen"
        case .cardPending:       return "Pending"
        case .cardClosed:        return "Closed"
        case .cardView:          return "View Card"
        case .emailVerified:     return "Email verified"
        case .emailUnverified:   return "Email unverified"
        case .smsVerified:       return "SMS verified"
        case .smsUnverified:     return "SMS unverified"
        case .twoFactorEnabled:  return "2FA on"
        case .twoFactorDisabled: return "2FA off"
        }
    }
    
    // MARK: - Color
    
    var color: Color {
        switch self {
        case .cardPrimary:                              return .blue
        case .cardActive, .emailVerified,
                .smsVerified, .twoFactorEnabled:        return Color.movo.success
        case .cardInactive, .emailUnverified,
                .smsUnverified, .twoFactorDisabled:     return Color.movo.textDisabled
        case .cardFrozen:                               return .cyan
        case .cardPending:                              return Color.movo.warning
        case .cardClosed:                               return Color.movo.danger
        case .cardView:                                 return .indigo
        }
    }
    
    // MARK: - Icon (optional)
    
    var icon: String? {
        switch self {
        case .cardPrimary:       return nil
        case .cardActive:        return nil
        case .cardInactive:      return "minus.circle.fill"
        case .cardFrozen:        return "snowflake"
        case .cardPending:       return "clock.fill"
        case .cardClosed:        return "xmark.circle.fill"
        case .cardView:          return nil
        case .emailVerified:     return "envelope.badge.checkmark"
        case .emailUnverified:   return "envelope.badge"
        case .smsVerified:       return "iphone.badge.checkmark"
        case .smsUnverified:     return "iphone"
        case .twoFactorEnabled:  return "lock.shield.fill"
        case .twoFactorDisabled: return "lock.open.fill"
        }
    }
    
    // MARK: - Actionable
    
    var isActionable: Bool {
        switch self {
        case .cardFrozen, .cardInactive, .cardPending,
                .emailUnverified, .smsUnverified, .twoFactorDisabled:
            return true
        default:
            return false
        }
    }
}

// MARK: - StatusBadge

struct StatusBadge: View {
    
    let status: BadgeStatus
    var size: BadgeSize = .regular
    var action: (() -> Void)? = nil
    
    // MARK: Size
    
    enum BadgeSize {
        case small, regular, large
        
        var font: Font {
            switch self {
            case .small:   return .system(size: 10, weight: .semibold)
            case .regular: return .caption.weight(.medium)
            case .large:   return .subheadline.weight(.medium)
            }
        }
        var hPad: CGFloat   { switch self { case .small: 7;  case .regular: 10; case .large: 14 } }
        var vPad: CGFloat   { switch self { case .small: 3;  case .regular: 5;  case .large: 7  } }
        var iconSize: CGFloat { switch self { case .small: 8; case .regular: 10; case .large: 13 } }
    }
    
    // MARK: Body
    
    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 4) {
                if let icon = status.icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .semibold))
                }
                
                Text(status.label)
                    .font(size.font)
                
                if action != nil {
                    MovoChevron(.disclosure, color: status.color)
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, size.hPad)
            .padding(.vertical, size.vPad)
            .background(status.color.opacity(0.10))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
            .overlay(
                action != nil
                ? Capsule().strokeBorder(status.color.opacity(0.2), lineWidth: 0.8)
                : nil
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .modifier(PulseModifier(
            active: status == .cardFrozen || status == .cardPending
        ))
    }
}

// MARK: - Pulse modifier

struct PulseModifier: ViewModifier {
    let active: Bool
    @State private var pulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(active && pulsing ? 1.04 : 1.0)
            .animation(
                active ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default,
                value: pulsing
            )
            .onAppear { if active { pulsing = true } }
    }
}
