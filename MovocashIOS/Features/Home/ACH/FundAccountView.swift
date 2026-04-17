//
//  FundAccountView.swift
//  MovocashIOS
//
//  Created by Vinu on 09/04/26.
//

import SwiftUI

struct FundAccountView: View {
    
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var vm: ACHViewModel
    @StateObject private var achVM: PlaidAchViewModel
    
    let primaryAccount: SavingsAccountInfo
    /// Called when the user taps "Connect Bank Account" on the empty state.
    let onConnectBank: () -> Void
    
    init(container: AppContainer, primaryAccount: SavingsAccountInfo, onConnectBank: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: container.makeACHViewModel())
        _achVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
        self.primaryAccount = primaryAccount
        self.onConnectBank = onConnectBank
    }
    
    @State private var selectedAccount: ACHAccount?
    @State private var amount: String = ""
    @State private var isAccountPickerExpanded: Bool = false
    @State private var showConfirmSheet: Bool = false
    
    private var enteredAmount: Decimal { Decimal(string: amount) ?? 0 }

    private var amountExceedsBalance: Bool {
        guard let account = selectedAccount else { return false }
        return enteredAmount > account.plaidAccountBalance
    }

    private var isFormValid: Bool {
        selectedAccount != nil &&
        enteredAmount > 0 &&
        !amountExceedsBalance
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if vm.state == .loading && vm.accounts.isEmpty {
                    SpinnerView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    fundForm
                }
            }
            .task { await vm.fetchAccounts() }
            .onChange(of: vm.accounts) { accounts in
                if selectedAccount == nil {
                    selectedAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
                }
            }
            .sheet(isPresented: $showConfirmSheet) {
                confirmationSheet
                    .padding(.top, 30)
                    .presentationDetents([.height(420)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Fund Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.primary)
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    
    // MARK: - Fund Form
    
    private var fundForm: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                amountSection
                accountSection
                primaryAccountSection
                confirmButton
            }
            .padding(16)
        }
    }
    
    // MARK: - Account Selection
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("From:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            
            VStack(spacing: 0) {
                // Selected / single account row
                let display = selectedAccount ?? vm.accounts.first
                if let display {
                    Button {
                        if vm.accounts.count > 1 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAccountPickerExpanded.toggle()
                            }
                        }
                    } label: {
                        HStack(spacing: 14) {
                            institutionLogoView(display)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(display.accountName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(display.institutionName)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Text("\(display.accountNumber.suffix(4))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(display.formattedBalance)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                                if vm.accounts.count > 1 {
                                    Image(systemName: isAccountPickerExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                // Dropdown options (multiple accounts only)
                if isAccountPickerExpanded {
                    ForEach(vm.accounts, id: \.achAccountId) { account in
                        Divider().padding(.horizontal, 16)
                        dropdownRow(account)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
    
    private func institutionLogoView(_ account: ACHAccount) -> some View {
        ZStack {
            Circle()
                .fill(Color.softBlue.opacity(0.1))
                .frame(width: 44, height: 44)
            if let uiImage = account.logoImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            } else {
                Image(systemName: "building.columns")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.softBlue)
            }
        }
    }
    
    private func dropdownRow(_ account: ACHAccount) -> some View {
        let isSelected = selectedAccount?.achAccountId == account.achAccountId
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedAccount = account
                isAccountPickerExpanded = false
            }
        } label: {
            HStack(spacing: 14) {
                institutionLogoView(account)
                VStack(alignment: .leading, spacing: 3) {
                    Text(account.accountName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(account.institutionName)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("\(account.accountNumber.suffix(4))")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(account.formattedBalance)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                        .foregroundStyle(isSelected ? Color.softBlue : Color(.systemGray3))
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Primary Account (To)
    
    private var primaryAccountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("To:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.softBlue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "building.2")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.softBlue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(primaryAccount.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(primaryAccount.maskedAccountNumber)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(primaryAccount.formattedBalance)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
    
    // MARK: - Amount Input
    
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Amount:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            HStack {
                Text("$")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 18, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(amountExceedsBalance ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )

            if amountExceedsBalance, let account = selectedAccount {
                Text("Amount exceeds available balance of \(account.formattedBalance)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Confirm Button

    private var confirmButton: some View {
        PrimaryButton(
            title: "Confirm Transfer",
            backgroundColor: isFormValid ? Color.primary : Color(.systemGray4),
            textColor: isFormValid ? .white : .gray
        ) {
            guard isFormValid else { return }
            showConfirmSheet = true
        }
        .disabled(!isFormValid)
        .frame(height: 52)
    }

    // MARK: - Confirmation Sheet

    private var confirmationSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Check the information")
                .font(.system(size: 22, weight: .bold))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 16) {
                // Amount
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amount:")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    amountDisplay
                }

                Divider()

                // Available
                VStack(alignment: .leading, spacing: 2) {
                    Text("Available:")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text("1-3 business days")
                        .font(.system(size: 16, weight: .semibold))
                }

                Divider()

                // From / To
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From:")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        Text(selectedAccount?.accountName ?? "")
                            .font(.system(size: 16, weight: .semibold))
                        if let account = selectedAccount {
                            Text("\(account.accountNumber.suffix(4))")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("To:")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        Text(primaryAccount.displayName)
                            .font(.system(size: 16, weight: .semibold))
                        Text(primaryAccount.maskedAccountNumber)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            
            HStack(spacing: 12) {
                PrimaryButton(title: "Cancel",
                              backgroundColor: Color.secondary,
                              textColor: Color.gray) {
                    showConfirmSheet = false
                }
                
                PrimaryButton(
                    title: "Confirm",
                    backgroundColor: Color.primary,
                    isLoading: vm.state == .loading
                ) {
                    guard let account = selectedAccount else { return }
                    Task {
                        let request = ACHRequest(
                            amount: Int(amount) ?? 0,
                            achAccountId: account.achAccountId,
                            userAction: "SUBMITS_ACH_DEPOSIT"
                        )
                        let success = await vm.initiateTransfer(request: request)
                        if success {
                            showConfirmSheet = false
                            ToastManager.shared.show("Transfer initiated successfully.", style: .success, position: .bottom)
                            dismiss()
                        }
                    }
                }
                .frame(height: 52)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
    }

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("$")
                .font(.system(size: 28, weight: .bold))
            let parts = amount.split(separator: ".")
            Text(String(parts.first ?? "0"))
                .font(.system(size: 48, weight: .bold))
            Text(".\(parts.count > 1 ? String(parts[1]) : "00")")
                .font(.system(size: 28, weight: .bold))
        }
    }
}
