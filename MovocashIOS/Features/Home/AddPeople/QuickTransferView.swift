//
//  QuickTransferView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/03/26.
//

import SwiftUI

struct QuickTransferView: View {

    let contact: AppContact

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @ObservedObject private var savingVM: SavingsAccountViewModel
    @StateObject private var transVM: TransactionViewModel

    @State private var amountText = ""
    @State private var descriptionText = ""
    @State private var selectedAccount: SavingsAccountDetailsResponse?
    @State private var isTransferring = false

    init(
        contact: AppContact,
        container: AppContainer,
        savingVM: SavingsAccountViewModel
    ) {
        self.contact = contact
        _savingVM = ObservedObject(wrappedValue: savingVM)
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
    }

    private var amount: Double { Double(amountText) ?? 0 }
    private var isValid: Bool { amount > 0 && selectedAccount != nil }
    private var accounts: [SavingsAccountDetailsResponse] {
        savingVM.accountList?.accounts ?? []
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    contactCard
                    accountCard
                    amountCard
                    descriptionCard
                    sendButton
                        .padding(.top, 15)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle("Send Money")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                }
            }
        }
        .task { await initAccounts() }
        .globalAlert()
    }

    // MARK: - Contact Card

    private var contactCard: some View {
        HStack(spacing: 14) {
            contactAvatar(initials: contact.initials, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.system(size: 16, weight: .semibold))
                Text(contact.phone)
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    // MARK: - Amount Card

    private var amountCard: some View {
        VStack(spacing: 10) {
            Text("AMOUNT")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.gray)
            HStack(alignment: .top, spacing: 4) {
                Text("$")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.gray)
                    .padding(.top, 6)
                TextField("0", text: $amountText)
                    .font(.system(size: 48, weight: .light))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    // MARK: - Description Card

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DESCRIPTION")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.gray)
            TextField("Add a note (optional)", text: $descriptionText)
                .font(.system(size: 15))
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    // MARK: - Account Card

    private var accountCard: some View {
        HStack(spacing: 0) {
            Text("From account:")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if savingVM.state == .loading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity)
                } else if accounts.isEmpty {
                    Text("No accounts")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity)
                } else {
                    Menu {
                        ForEach(accounts) { account in
                            Button {
                                selectedAccount = account
                            } label: {
                                Text("\(account.nickname ?? account.clientName)  \(account.maskedAccountNumber)")
                            }
                        }
                    } label: {
                        HStack {
                            if let account = selectedAccount {
                                Text("\(account.nickname ?? account.clientName)  \(account.maskedAccountNumber)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Select")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .animation(.none, value: selectedAccount?.id)
                    }
                }
            }
        }
        .animation(.none, value: savingVM.state)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    // MARK: - Send Button

    private var sendButton: some View {
        PrimaryButton(title: "Send Money", isLoading: isTransferring, isEnabled: isValid) {
            UIApplication.shared.dismissKeyboard()
            Task { await sendMoney() }
        }
    }

    // MARK: - Avatar

    private func contactAvatar(initials: String, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundColor(Color.softBlue)
        }
    }

    // MARK: - Actions

    private func initAccounts() async {
        // If dashboard hasn't loaded accounts yet, load them now
        if savingVM.accountList == nil {
            await savingVM.loadAccounts()
        }
        // Auto-select primary account, fall back to first if none marked primary
        if selectedAccount == nil {
            selectedAccount = savingVM.accountList?.accounts.first(where: { $0.isPrimary })
                ?? savingVM.accountList?.accounts.first
        }
        // Silently refresh in background — no spinner
        await savingVM.refreshAccountsSilently()
        if selectedAccount == nil {
            selectedAccount = savingVM.accountList?.accounts.first(where: { $0.isPrimary })
                ?? savingVM.accountList?.accounts.first
        }
    }

    private func sendMoney() async {
        guard let fromAccount = selectedAccount else { return }
        isTransferring = true
        defer { isTransferring = false }
        
        let sanitized = PhoneNumberValidator.sanitize(contact.phone)
        guard PhoneNumberValidator.isValidUSNumber(sanitized) else {
            AlertManager.shared.showError("Enter a valid phone number")
            return
        }

        let normalizedPhone = PhoneNumberValidator.normalize(sanitized)

        let request = TransactionRequest.Internal(
            description: descriptionText,
            amount: amount,
            toAccountId: 0,
            toClientId: 0,
            fromAccountId: fromAccount.id,
            phoneNumber: normalizedPhone
        )
        guard await transVM.submitInternalTransfer(request: request) else { return }
        ToastManager.shared.show("Money sent successfully.", style: .success, position: .bottom)
        dismiss()
    }
}
