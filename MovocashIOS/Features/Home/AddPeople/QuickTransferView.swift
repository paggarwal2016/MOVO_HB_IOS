//
//  QuickTransferView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/03/26.
//

import SwiftUI

struct QuickTransferView: View {

    let contact: ContactRecord

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var savingVM: SavingsAccountViewModel
    @StateObject private var transVM: TransactionViewModel

    @State private var amountText = ""
    @State private var descriptionText = ""
    @State private var selectedAccount: SavingsAccountInfo?

    init(
        contact: ContactRecord,
        container: AppContainer
    ) {
        self.contact = contact
        _savingVM = StateObject(wrappedValue: container.makeSavingsAccountViewModel())
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
    }

    private var amount: Double { Double(amountText) ?? 0 }
    private var isValid: Bool { amount > 0 && selectedAccount != nil }
    private var accounts: [SavingsAccountInfo] {
        savingVM.accountList?.data.accounts ?? []
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MovoBackground()

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
        .task { await loadAccounts() }
        .globalAlert()
    }

    // MARK: - Contact Card

    private var contactCard: some View {
        HStack(spacing: 14) {
            contactAvatar(initials: contact.initials, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.nickname ?? "")
                    .font(.system(size: 16, weight: .semibold))
                Text(contact.phoneNumber ?? "")
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
        Button {
            UIApplication.shared.dismissKeyboard()
            Task { await sendMoney() }
        } label: {
            Text("Send Money")
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isValid ? Color.primary : Color(.systemGray5))
                .foregroundStyle(isValid ? Color.white : Color(.tertiaryLabel))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isValid)
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

    private func loadAccounts() async {
        await savingVM.loadAccounts()
        if selectedAccount == nil {
            selectedAccount = savingVM.accountList?.data.accounts.first(where: { $0.isPrimary })
        }
    }

    private func sendMoney() async {
        guard let fromAccount = selectedAccount else { return }
        
        let rawPhone = contact.phoneNumber ?? ""
        let withCountry = rawPhone.hasPrefix("+1") ? rawPhone : "+1\(rawPhone.filter(\.isNumber))"
        let sanitized = PhoneNumberValidator.sanitize(withCountry)
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
            phoneNumber: normalizedPhone,
            userAction: "Internal-Transfer",
            nickname: contact.nickname ?? ""
        )
        guard await transVM.submitInternalTransfer(request: request) else { return }
        ToastManager.shared.show("Money sent successfully.", style: .success, position: .bottom)
        dismiss()
    }
}
