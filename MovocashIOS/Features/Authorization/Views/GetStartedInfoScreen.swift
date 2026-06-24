//
//  GetStartedInfoScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/04/26.
//

import SwiftUI

// MARK: - Model

private struct LegalItem: Identifiable {
    let id             = UUID()
    let subtitle:       String
    let documentType:  DocumentType
}

// MARK: - View

struct GetStartedInfoScreen: View {

    // MARK: Callbacks
    let onReady:  () -> Void
    let onBack:   () -> Void

    // MARK: Dependencies
    let container: AppContainer

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
        LegalItem(subtitle: "Deposit account agreement and disclosures",
                  documentType: .tos),
    ]

    private var allAccepted: Bool {
        legalItems.allSatisfy { acceptedItems.contains($0.documentType.title) }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()
            
            VStack(spacing: 0) {
               
                topBar
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.sm)
                    .padding(.bottom, DesignTokens.Spacing.xxl)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        requirementsSection
                            .padding(.bottom, DesignTokens.Spacing.xxl)
                        documentsSection
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xxxl + 60)
                }
                continueButton
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.lg)
            }
            .sheet(item: $selectedItem) { item in
                PDFViewScreen(documentType: item.documentType, container: container) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        _ = acceptedItems.insert(item.documentType.title)
                    }
                }
            }
        }
    }
}

// MARK: - Top Nav

private extension GetStartedInfoScreen {
    
    private var topBar: some View {
        HStack {
            CustomBackButton() {
                onBack()
            }
            Spacer()
        }
    }
}

// MARK: - Requirements

private extension GetStartedInfoScreen {

    var requirementsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ShieldCheckIcon(size: 18, tint: Color.movo.accent)
                Text("Eligibility")
                    .textStyle(Typography.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.movo.textTertiary)
            }

            VStack(spacing: 0) {
                ForEach(Array(requirements.enumerated()), id: \.offset) { index, item in

                    HStack(spacing: DesignTokens.Spacing.md) {
                        EligibilityCheckIcon(size: 18, tint: Color.movo.accent)
                        Text(item)
                            .textStyle(Typography.body)
                            .foregroundStyle(Color.movo.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 11)
                 
                    if index < requirements.count - 1 {
                        Rectangle()
                            .fill(Color.movo.textTertiary.opacity(0.10))
                            .frame(height: DesignTokens.Stroke.hairline)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg - 2)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                    .fill(Color.movo.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                    .strokeBorder(Color.movo.borderStrong, lineWidth: DesignTokens.Stroke.hairline)
            )
        }
    }
}

// MARK: - Documents

private extension GetStartedInfoScreen {

    var documentsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                DocumentBadgeIcon(size: 18, stroke: Color.movo.accent)
                Text("Account Disclosures")
                    .textStyle(Typography.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.movo.textTertiary)
            }
            
            VStack(spacing: DesignTokens.Spacing.sm + 2) {
                ForEach(legalItems) { item in
                    documentCard(item)
                }
            }
        }
    }

    
    func documentCard(_ item: LegalItem) -> some View {
        let isAccepted = acceptedItems.contains(item.documentType.title)

        let iconStroke = isAccepted
            ? Color.movo.accent
            : Color.movo.textTertiary

        let iconAccent = isAccepted
            ? Color.movo.accent
            : Color.movo.textPrimary

        return Button {
            selectedItem = item
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                // MARK: Illustration
                Group {
                    DocumentLinesIcon(
                        stroke: iconStroke,
                        accent: iconAccent
                    )
                }
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.Radius.lg,
                        style: .continuous
                    )
                    .fill(iconStroke.opacity(isAccepted ? 0.10 : 0.06))
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.Radius.lg,
                        style: .continuous
                    )
                    .strokeBorder(
                        iconStroke.opacity(isAccepted ? 0.25 : 0.14),
                        lineWidth: DesignTokens.Stroke.hairline
                    )
                )

                // MARK: Title + Subtitle

                VStack(alignment: .leading, spacing: 2) {

                    Text(item.documentType.title)
                        .textStyle(Typography.body)
                        .foregroundStyle(Color.movo.textPrimary)

                    Text(item.subtitle)
                        .textStyle(Typography.caption)
                        .foregroundStyle(Color.movo.textTertiary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                // MARK: Selection State

                if isAccepted {

                    ReviewedCheckPill(
                        size: 26,
                        fill: Color.movo.accent,
                        checkColor: Color.movo.background
                    )

                } else {

                    UnreadChevronIcon(
                        size: 14,
                        tint: Color.movo.textTertiary
                    )
                    .padding(.trailing, 4)
                }
            }
            .padding(DesignTokens.Spacing.md + 2)
            .background(
                RoundedRectangle(
                    cornerRadius: DesignTokens.Radius.xl,
                    style: .continuous
                )
                .fill(Color.movo.surface)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: DesignTokens.Radius.xl,
                    style: .continuous
                )
                .strokeBorder(
                    isAccepted
                    ? Color.movo.accent.opacity(0.30)
                    : Color.movo.borderStrong.opacity(0.18),
                    lineWidth: DesignTokens.Stroke.thin
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(
            .easeInOut(duration: DesignTokens.Motion.fast),
            value: isAccepted
        )
    }
}

// MARK: - Bottom Bar

private extension GetStartedInfoScreen {


    private var continueButton: some View {
        Button(action: { onReady() }) {
            Text("Accept & continue")
                .textStyle(Typography.buttonLarge)
                .foregroundStyle(
                    allAccepted
                    ? Color.movo.onAccent
                    : Color.movo.accent.opacity(0.55)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                        .fill(allAccepted ? Color.movo.accent : Color.movo.accent.opacity(0.22))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                        .strokeBorder(
                            allAccepted ? Color.clear : Color.movo.accent.opacity(0.35),
                            lineWidth: DesignTokens.Stroke.thin
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!allAccepted)
        .animation(.easeInOut(duration: DesignTokens.Motion.standard), value: allAccepted)
    }

}
