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
    
    var body: some View {
        ZStack(alignment: .bottom) {
            MovoBackground()
            AmbientGlowView()
            
            VStack(spacing: 0) {
                
                topBar
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.sm)
                    .padding(.bottom, DesignTokens.Spacing.xxl)
                
                VerifyIdentityIllustration()
                    .frame(width: 84, height: 84)
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
                
                headerBlock
                    .padding(.horizontal, Spacing.xxl + 4)
                    .padding(.bottom, Spacing.xxxl)
                
                documentList
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xl + 4)
                
                infoCard
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                
                Spacer()
                
                ctaFooter
            }
        }
        .background(Color.movo.background)
    }
    
    
    private var ctaFooter: some View {
        VStack(spacing: 0) {
            
            Button(action: {
                onContinue()
            }) {
                Text("Continue")
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .disabled(selectedDocument == nil)
            .opacity(selectedDocument != nil ? 1.0 : 0.45)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl + 4)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var topBar: some View {
        HStack {
            CustomBackButton() {
                onBack()
            }
            Spacer()
        }
    }
    
    private var headerBlock: some View {
        VStack(spacing: 12) {
            
            Text("Verify Your Identity")
                .textStyle(Typography.heroTitle)
                .foregroundColor(Color.movo.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("Pick a document to verify your identity.\nMake sure it's valid and clearly readable.")
                .textStyle(Typography.subtitle)
                .foregroundColor(Color.movo.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }
    
    private var documentList: some View {
        VStack(spacing: Spacing.sm + 2) {
            ForEach(IDDocumentType.allCases) { doc in
                DocumentRow(
                    document: doc,
                    isSelected: selectedDocument == doc.label,
                    action: {
                        selectedDocument = doc.label
                    }
                )
            }
        }
    }
}



private var infoCard: some View {
    HStack(alignment: .top, spacing: Spacing.md + 2) {
        Image(systemName: "info.circle")
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(Color.movo.accent)
            .padding(.top, 1)
        
        VStack(alignment: .leading, spacing: 4) {
            Text("You'll need photo ID")
                .textStyle(Typography.cardHero)
                .foregroundColor(Color.movo.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("Please have your passport, driver's license, or state ID handy.")
                .textStyle(Typography.captionSmall)
                .foregroundColor(Color.movo.textTertiary)
                .lineSpacing(2)
        }
        
        Spacer(minLength: 0)
    }
    .padding(Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
        RoundedRectangle(cornerRadius: Radius.heroCard)
            .fill(Color.movo.surface.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.heroCard)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
            )
    )
}



// MARK: - Document Row

private struct DocumentRow: View {
    let document: IDDocumentType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md + 2) {
                // Leading icon
                Image(systemName: document.systemIcon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color.movo.accent)
                    .frame(width: 32, height: 32)
                
                Text(document.label)
                    .textStyle(Typography.body)
                    .foregroundColor(Color.movo.textPrimary)
                
                Spacer()
                
                // Radio
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.movo.accent : Color.movo.borderStrong,
                            lineWidth: isSelected ? 1.5 : Stroke.thin
                        )
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.movo.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md + 4)
            .background(
                RoundedRectangle(cornerRadius: Radius.heroCard)
                    .fill(Color.movo.surface.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.heroCard)
                            .strokeBorder(
                                isSelected ? Color.movo.accentBorder : Color.movo.border,
                                lineWidth: Stroke.hairline
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}


public enum IDDocumentType: String, CaseIterable, Identifiable, Sendable {
    case driversLicense
    case passport
    case nationalID
    
    public var id: String { rawValue }
    
    public var label: String {
        switch self {
        case .driversLicense: return "Driver's License"
        case .passport:       return "Passport"
        case .nationalID:     return "National ID"
        }
    }
    
    public var systemIcon: String {
        switch self {
        case .driversLicense: return "car.fill"
        case .passport:       return "globe"
        case .nationalID:     return "creditcard.fill"
        }
    }
}
