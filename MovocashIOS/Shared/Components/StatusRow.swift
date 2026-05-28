//
//  StatusRow.swift
//  MovocashIOS
//
//  Created by Movo Developer on 18/03/26.
//

import Foundation
import SwiftUI

// MARK: -  Style

struct StatusStyle {
    let label: String
    let color: Color
    let icon: String
}

// MARK: - StatusRow

struct StatusRow: View {
    let label: String
    let isRequired: Bool
    let trueStyle: StatusStyle
    let falseStyle: StatusStyle
    var action: (() -> Void)? = nil
    
    private var current: StatusStyle {
        isRequired ? trueStyle : falseStyle
    }
    
    var body: some View {
        Button {
            action?()
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(Color.movo.textTertiary)
                    .font(.subheadline)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: current.icon)
                        .font(.caption2)
                    Text(current.label)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(current.color.opacity(0.12))
                .foregroundStyle(current.color)
                .clipShape(Capsule())
                
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.movo.textDisabled)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}



// MARK: - Preset Styles (reuse across the app)

extension StatusStyle {
    static let required  = StatusStyle(label: "Required",    color: .orange, icon: "exclamationmark.circle")
    static let complete  = StatusStyle(label: "Complete",    color: .green,  icon: "checkmark.circle")
    static let allowed   = StatusStyle(label: "Allowed",     color: .green,  icon: "checkmark.circle")
    static let notAllowed = StatusStyle(label: "Not allowed", color: .red,   icon: "xmark.circle")
    static let connected = StatusStyle(label: "Connected",   color: .green,  icon: "link")
    static let active    = StatusStyle(label: "Active",      color: .green,  icon: "checkmark.circle")
    static let deactivated = StatusStyle(label: "Deactivated", color: .red,  icon: "xmark.circle")
}
