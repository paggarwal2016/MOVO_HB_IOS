//
//  EmptyStateView.swift
//  MovocashIOS
//

import SwiftUI

struct EmptyStateView: View {
    let image: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Image(systemName: image)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }
}
