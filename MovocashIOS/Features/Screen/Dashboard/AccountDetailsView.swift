//
//  DashboardAccountView.swift
//  MovocashIOS
//
//  Created by Vinu on 15/05/26.
//

import Foundation
import SwiftUI
import Combine

struct AccountDetailsView: View {
    let account: SavingsAccountInfo
    var onNicknameUpdated: ((String) -> Void)?

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var isCopied = false
    @State private var showEditNickname = false
    @State private var displayNickname: String

    init(account: SavingsAccountInfo, onNicknameUpdated: ((String) -> Void)? = nil) {
        self.account = account
        self.onNicknameUpdated = onNicknameUpdated
        _displayNickname = State(initialValue: account.nickname ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            balanceHero
            
            Rectangle()
                .fill(Color.movo.elevated)
                .frame(height: 1)
                .padding(.horizontal, Spacing.xl)
            
            rowDetail
        }
        .padding(.top, Spacing.xxl)
        .sheet(isPresented: $showEditNickname) {
            EditNicknameView(currentNickname: displayNickname) { newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayNickname = newValue
                }
                onNicknameUpdated?(newValue)
            }
            .presentationDetents([.height(310)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.movo.surface)
            .presentationCornerRadius(Radius.sheet)
        }

    }
    
    private var header: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "banknote")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.movo.accent)
                    .frame(width: 28, height: 28)
                    .background(Color.movo.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.sm))

                Text("\(account.isPrimary ? "PRIMARY" : "ACCOUNT") · ••\(account.accountNumber.suffix(4))")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(Color.movo.textSecondary)
            }
            Spacer()
            CircularNavButton(systemName: "pencil") {
                showEditNickname = true
            }
            .accessibilityLabel("Edit nickname")
            CircularNavButton(systemName: "xmark") {
                dismiss()
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
    }
    
    
    // MARK: Balance hero
    
    private var balanceHero: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(displayNickname)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.movo.textPrimary)
                .padding(.top, Spacing.lg)

            Text(account.formattedBalance)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(Color.movo.textPrimary)
                .monospacedDigit()
                .tracking(-0.8)

            HStack(spacing: Spacing.sm) {
                Text("AVAILABLE BALANCE")
                    .font(.system(size: 10))
                    .tracking(0.6)
                    .foregroundStyle(Color.movo.textSecondary)
                if account.isActive { StatusPill("ACTIVE") }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.md)
    }
    
    private var rowDetail: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("ACCOUNT NUMBER")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(Color.movo.textSecondary)

                Text(account.accountNumber)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.movo.textPrimary)
                    .monospacedDigit()
            }

            Spacer()

            copyButton
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
    }
    
    private var copyButton: some View {
        Button {
            UIPasteboard.general.string = account.accountNumber
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                isCopied = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCopied = false
                }
            }
            
        } label: {
            ZStack {
                Image(systemName: "doc.on.doc")
                    .opacity(isCopied ? 0 : 1)
                    .scaleEffect(isCopied ? 0.5 : 1.0)
                
                Image(systemName: "checkmark")
                    .opacity(isCopied ? 1 : 0)
                    .scaleEffect(isCopied ? 1.1 : 0.5)
                    .rotationEffect(.degrees(isCopied ? 0 : -45))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(
                isCopied
                ? Color.movo.accent
                : Color.movo.textTertiary
            )
            .frame(width: 32, height: 32)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .stroke(Color.movo.elevated, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy account number")
    }
}





struct EditNicknameView: View {
    let currentNickname: String
    let onSave: (String) -> Void

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @FocusState private var isFocused: Bool

    private let maxLength = 30

    init(currentNickname: String, onSave: @escaping (String) -> Void) {
        self.currentNickname = currentNickname
        self.onSave = onSave
        _draft = State(initialValue: currentNickname)
    }

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmed.isEmpty
        && trimmed != currentNickname
        && trimmed.count <= maxLength
    }

    var body: some View {
        VStack(spacing: 0) {
            iconHeader
            inputSection
            actionRow
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xxl)
        .background(Color.movo.surface.ignoresSafeArea())
        .onAppear { isFocused = true }
    }
    
    private var iconHeader: some View {
        HStack(alignment: .top, spacing: Spacing.md) {

            Image(systemName: "pencil")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.movo.accent)
                .frame(width: 44, height: 44)
                .background(
                    Color.movo.accent.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: Radius.xl)
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {

                Text("Edit nickname")
                    .textStyle(Typography.cardHero)
                    .foregroundStyle(Color.movo.textPrimary)

                Text("Give your primary account a name that's easy to recognize.")
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(.top, Spacing.xxl)
        .padding(.horizontal, Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("NICKNAME")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(Color.movo.textSecondary)
                Spacer()
            }

            HStack(spacing: Spacing.sm) {
                TextField("", text: $draft)
                    .focused($isFocused)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.movo.textPrimary)
                    .tint(Color.movo.accent)
                    .submitLabel(.done)
                    .onSubmit { if canSave { save() } }
                    .onChangeCompat(of: draft) { new in
                        if new.count > maxLength {
                            draft = String(new.prefix(maxLength))
                        }
                    }

                if !draft.isEmpty {
                    CircularNavButton(systemName: "xmark") {
                        draft = ""
                    }
                    .frame(width: 16, height: 16)
                    .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: 48)
            .background(Color.movo.background,
                        in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(isFocused ? Color.movo.accentBorder : Color.movo.borderStrong,
                        lineWidth: 1))
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .animation(.easeInOut(duration: 0.15), value: draft.isEmpty)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xxl)
    }

    private var actionRow: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: { dismiss() } ) {
                Text("Cancel")
            }
            .buttonStyle(OutlineButtonStyle())
            .frame(maxWidth: .infinity)

            Button(action: { save() }) {
                Text("Save")
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .disabled(!canSave)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xxl)
    }

    private func save() {
        onSave(trimmed)
        dismiss()
    }
}
