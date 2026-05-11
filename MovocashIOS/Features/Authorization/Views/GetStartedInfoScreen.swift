//
//  GetStartedInfoScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/04/26.
//

import SwiftUI

// MARK: - Model

private struct LegalItem: Identifiable {
    let id           = UUID()
    let title:         String
    let subtitle:      String
    let documentType:  DocumentType
}

// MARK: - View

struct GetStartedInfoScreen: View {

    // MARK: Callbacks
    let onReady:  () -> Void
    let onNotNow: () -> Void
    let onBack:   () -> Void

    // MARK: Dependencies
    let container: AppContainer
    var isLoading: Bool = false

    // MARK: State
    @Binding var acceptedItems: Set<String>
    @State private var selectedItem: LegalItem?

    // MARK: Data
    private let requirements: [String] = [
        "Be 18 or older",
        "Be a US resident",
        "Have a US mobile number",
        "Be a US tax resident"
    ]

    private let legalItems: [LegalItem] = [
        LegalItem(title: "Privacy Policy",
                  subtitle: "How we handle your personal data",
                  documentType: .privacy),
        LegalItem(title: "Herring Privacy Policy",
                  subtitle: "Herring Bank's privacy practices",
                  documentType: .herringPrivacy),
        LegalItem(title: "Terms of Use Agreement",
                  subtitle: "Rules and conditions for using Movo",
                  documentType: .tos),
        LegalItem(title: "Electronic Consent",
                  subtitle: "Digital agreement and consent",
                  documentType: .cardholderAgreement)
    ]

    private var allAccepted: Bool {
        legalItems.allSatisfy { acceptedItems.contains($0.title) }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    requirementsSection
                    documentsSection
                    Spacer().frame(height: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            bottomBar
        }
        .background(Color(.systemBackground))
        .sheet(item: $selectedItem) { item in
            PDFViewScreen(documentType: item.documentType, container: container) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    _ = acceptedItems.insert(item.title)
                }
            }
        }
    }
}

// MARK: - Top Nav

private extension GetStartedInfoScreen {

    var navBar: some View {
        HStack {
            BackButton { onBack() }
            Spacer()
            Text("\(acceptedItems.count)/\(legalItems.count) accepted")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Header

private extension GetStartedInfoScreen {

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Legal Agreements")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
            Text("Open each document, read it, and tap **Accept** inside to continue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Requirements

private extension GetStartedInfoScreen {

    var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Eligibility", icon: "checkmark.seal.fill")

            VStack(spacing: 0) {
                ForEach(Array(requirements.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.primary)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 16)

                    if index < requirements.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Documents

private extension GetStartedInfoScreen {

    var documentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Documents to accept", icon: "doc.fill")

            VStack(spacing: 12) {
                ForEach(legalItems) { item in
                    documentCard(item)
                }
            }
        }
    }

    func documentCard(_ item: LegalItem) -> some View {
        let isAccepted = acceptedItems.contains(item.title)

        return Button {
            selectedItem = item
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(item.documentType.iconColor.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: item.documentType.icon)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(item.documentType.iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isAccepted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.primary)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    (isAccepted ? Color.primary : Color(UIColor.separator)).opacity(0.5),
                    lineWidth: 1.5
                )
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isAccepted)
    }
}

// MARK: - Bottom Bar

private extension GetStartedInfoScreen {

    var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 10) {
                PrimaryButton(title: "Accept All & Continue", isLoading: isLoading, isEnabled: allAccepted) {
                    onReady()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Helpers

private extension GetStartedInfoScreen {

    func sectionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
