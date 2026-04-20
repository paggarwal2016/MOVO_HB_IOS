//
//  PickDocumentView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 07/04/26.
//

import SwiftUI

struct PickDocumentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lockManager: AppLockManager
    @EnvironmentObject var sessionManager: SessionManager

    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var selectedDocument: String? = nil

    private let options: [(icon: String, title: String)] = [
        ("car",        "Driver's License"),
        ("globe",      "Passport"),
        ("creditcard", "National ID")
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top bar ────────────────────────────────────────────────
                HStack {
                    BackButton { onBack() }
                    Spacer()
                }
                Spacer()

                // ── Icon ───────────────────────────────────────────────────
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(Color.primary)
                    .padding(.bottom, 32)

                // ── Title ──────────────────────────────────────────────────
                Text("Verify Your Identity")
                    .font(.title2.bold())
                    .padding(.bottom, 12)

                // ── Subtitle ───────────────────────────────────────────────
                Text("Pick a document to verify your identity. Make sure it's valid and clearly readable.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer().frame(height: 40)

                // ── Document options ───────────────────────────────────────
                VStack(spacing: 12) {
                    ForEach(options, id: \.title) { option in
                        DocumentOptionRow(
                            icon: option.icon,
                            title: option.title,
                            isSelected: selectedDocument == option.title
                        ) {
                            selectedDocument = option.title
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                PrimaryButton(title: "Continue", isEnabled: selectedDocument != nil) {
                    onContinue()
                }
                .disabled(selectedDocument == nil)
            }
            .padding()
        }
    }
}

// MARK: - DocumentOptionRow

private struct DocumentOptionRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Color.primary)
                    .frame(width: 32)

                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.25))
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                isSelected
                    ? Color.primary.opacity(0.06)
                    : Color(.secondarySystemBackground)
            )
            .clipShape(RoundedCorner(radius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
