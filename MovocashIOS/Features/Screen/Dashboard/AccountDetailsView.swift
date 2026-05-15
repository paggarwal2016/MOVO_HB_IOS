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
                .padding(.horizontal, 20)
            
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
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.movo.surface)
            .presentationCornerRadius(Radius.sheet)
        }

    }
    
    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "banknote")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.movo.accent)
                    .frame(width: 28, height: 28)
                    .background(Color.movo.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                
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
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }
    
    
    // MARK: Balance hero
    
    private var balanceHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(displayNickname)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.movo.textPrimary)
                .padding(.top, 18)
            
            Text(account.formattedBalance)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(Color.movo.textPrimary)
                .monospacedDigit()
                .tracking(-0.8)
            
            HStack(spacing: 8) {
                Text("AVAILABLE BALANCE")
                    .font(.system(size: 10))
                    .tracking(0.6)
                    .foregroundStyle(Color.movo.textSecondary)
                if account.isActive { StatusPill("ACTIVE") }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }
    
    private var rowDetail: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
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
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
                RoundedRectangle(cornerRadius: 8)
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
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(Color.movo.surface.ignoresSafeArea())
        .onAppear { isFocused = true }
    }

    private var iconHeader: some View {
        VStack(spacing: 0) {
            Image(systemName: "pencil")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.movo.accent)
                .frame(width: 44, height: 44)
                .background(Color.movo.accent.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 14))

            Text("Edit nickname")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.movo.textPrimary)
                .padding(.top, 12)

            Text("Give your primary account a name that's easy to recognize.")
                .font(.system(size: 13))
                .foregroundStyle(Color.movo.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NICKNAME")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(Color.movo.textSecondary)
                Spacer()
            }

            HStack(spacing: 8) {
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
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.movo.background,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.movo.accentBorder : Color.movo.borderStrong,
                        lineWidth: 1))
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .animation(.easeInOut(duration: 0.15), value: draft.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
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
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private func save() {
        onSave(trimmed)
        dismiss()
    }
}
