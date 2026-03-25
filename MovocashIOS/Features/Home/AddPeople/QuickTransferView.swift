//
//  QuickTransferView.swift
//  MovocashIOS
//
//  Created by Vinu on 25/03/26.
//

import SwiftUI

struct QuickTransferView: View {

    let contact: AppContact

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var savingVM: SavingsAccountViewModel

    @State private var amountText = ""
    @State private var selectedAccount: SavingsAccountDetailsResponse?

    init(
        contact: AppContact,
        savingVM: SavingsAccountViewModel = AppContainer.shared.makeSavingsAccountViewModel()
    ) {
        self.contact = contact
        _savingVM = StateObject(wrappedValue: savingVM)
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
                    amountCard
                    accountCard
                    Spacer().frame(height: 88)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            sendButton
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
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
                Text(contact.name)
                    .font(.system(size: 16, weight: .semibold))
                Text(contact.phone)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 4) {
                Text("$")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.secondary)
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

    // MARK: - Account Card

    private var accountCard: some View {
        HStack {
            Text("From account")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            if savingVM.state == .loading {
                ProgressView()
                    .scaleEffect(0.8)
            } else if accounts.isEmpty {
                Text("No accounts")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    ForEach(accounts) { account in
                        Button {
                            selectedAccount = account
                        } label: {
                            VStack(alignment: .leading) {
                                Text(account.nickname ?? account.clientName)
                                Text(account.maskedAccountNumber)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let account = selectedAccount {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(account.nickname ?? account.clientName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(account.maskedAccountNumber)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Select account")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
                .background(isValid ? AppColors.primary : Color(.systemGray5))
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
            selectedAccount = savingVM.accountList?.accounts.first(where: { $0.isPrimary })
        }
    }

    private func sendMoney() async {
        // TODO: Wire to external transfer API when endpoint is available
    }
}
