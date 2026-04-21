//
//  GetStartedInfoScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/04/26.
//

import SwiftUI

// MARK: - Model

private struct LegalItem: Identifiable {
    let id    = UUID()
    let icon:  String
    let title: String
}

// MARK: - View

struct GetStartedInfoScreen: View {

    // MARK: Callbacks
    let onReady:  () -> Void
    let onNotNow: () -> Void
    let onBack:   () -> Void

    // MARK: State
    @State private var acceptedItems: Set<String> = []

    // MARK: Data
    private let requirements: [String] = [
        "Be 18 or older",
        "Be a US resident",
        "Have a US mobile number",
        "Be a US tax resident"
    ]

    private let legalItems: [LegalItem] = [
        LegalItem(icon: "doc.plaintext", title: "Privacy Policy"),
        LegalItem(icon: "doc.plaintext", title: "Terms of Use Agreement"),
        LegalItem(icon: "signature",     title: "Electronic Consent")
    ]

    private var allAccepted: Bool {
        legalItems.allSatisfy { acceptedItems.contains($0.title) }
    }

    // MARK: Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                navigationBar
                titleSection
                requirementsSection
                Divider()
                legalSection
                Spacer().frame(height: 8)
                footerButtons
            }
            .padding()
        }
    }
}

// MARK: - Subviews

private extension GetStartedInfoScreen {

    var navigationBar: some View {
        HStack {
            BackButton { onBack() }
            Spacer()
        }
    }

    var titleSection: some View {
        Text("Accept Terms to continue")
            .titleStyle()
    }

    var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("To use Movo, you must:")
                .font(.subheadline)
                .foregroundColor(.secTcolor)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(requirements, id: \.self) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                        Text(item)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.preTcolor)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    var legalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Legal info")
                .font(.subheadline)
                .foregroundColor(.secTcolor)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(legalItems) { item in
                    legalRow(item)
                    Divider()
                }
            }
        }
    }

    var footerButtons: some View {
        PrimaryButton(title: "Accept & Continue", isEnabled: allAccepted) {
            onReady()
        }
    }
}

// MARK: - Legal Row

private extension GetStartedInfoScreen {

    func legalRow(_ item: LegalItem) -> some View {
        let isAccepted = acceptedItems.contains(item.title)

        return Button {
            acceptedItems.insert(item.title)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.preTcolor)
                    .frame(width: 24)

                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.preTcolor)

                Spacer()

                Image(systemName: isAccepted ? "checkmark" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isAccepted ? .primary : .secTcolor)
                    .animation(.easeInOut(duration: 0.2), value: isAccepted)
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}
