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
                .padding(.horizontal)
                .padding(.top)

                Spacer()

                // ── Header ─────────────────────────────────────────────────
                VStack(spacing: 16) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundStyle(Color.primary)

                    Text("Verify Your Identity")
                        .font(.title2.bold())

                    Text("Pick a document to verify your identity.\nMake sure it's valid and clearly readable.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

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
                .padding(.horizontal)

                Spacer()

                // ── Info card ──────────────────────────────────────────────
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You'll need photo ID")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.preTcolor)
                        Text("Please have your passport, driver's license, or state ID handy.")
                            .font(.system(size: 13))
                            .foregroundColor(.secTcolor)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()

                // ── Continue ───────────────────────────────────────────────
                PrimaryButton(title: "Continue", isEnabled: selectedDocument != nil) {
                    onContinue()
                }
                .disabled(selectedDocument == nil)
                .padding(.horizontal)
                .padding(.bottom)
            }
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
