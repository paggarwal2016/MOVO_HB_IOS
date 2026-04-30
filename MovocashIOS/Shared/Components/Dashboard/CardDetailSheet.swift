//
//  CardDetailSheet.swift
//  MovocashIOS
//
//  Created by Vinu on 30/04/26.
//

import SwiftUI

struct CardDetailSheet: View {

    let card: VCardListResponse
    let primaryAccountId: Int?
    let savingVM: SavingsAccountViewModel
    var onDeleted: () -> Void
    var onAddToWallet: (() -> Void)? = nil

    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var cvvRevealed = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    var body: some View {
        VStack(spacing: 0) {

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    CardItemView(card: card, isSelected: false)
                        .padding(.horizontal, 16)

                    detailRows

                    actionButtons
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        .alert("Delete Card", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await deleteCard() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this card? This action cannot be undone.")
        }
    }

    // MARK: - Detail Rows

    private var detailRows: some View {
        VStack(spacing: 0) {
            detailRow(label: "Card Number", value: card.maskedNumber) {
                Button {
                    UIPasteboard.general.string = card.cardNumber ?? card.maskedNumber
                    ToastManager.shared.show("Card number copied", style: .success, position: .bottom)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(.plain)
            }

            Divider().padding(.leading, 16)

            detailRow(label: "CVV", value: cvvRevealed ? (card.cvc2 ?? "•••") : "•••") {
                Button { cvvRevealed.toggle() } label: {
                    Image(systemName: cvvRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func detailRow(label: String, value: String, trailing: () -> some View) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .medium, design: value.contains("•") ? .monospaced : .default))
                    .foregroundStyle(.primary)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button { onAddToWallet?() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 15, weight: .medium))
                    Text("Add to Apple Wallet")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button { showDeleteConfirm = true } label: {
                HStack(spacing: 10) {
                    if isDeleting {
                        ProgressView().tint(.red)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .medium))
                        Text("Delete Card")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Delete

    private func deleteCard() async {
        guard let primaryId = primaryAccountId,
              let accountId = card.savingsAccountId else {
            ToastManager.shared.show("Unable to delete card.", style: .error, position: .bottom)
            return
        }
        isDeleting = true
        do {
            _ = try await savingVM.deleteSavingAccount(
                request: SavingsAccountRequest.DeleteAccount(
                    targetAccountId: primaryId,
                    accountId: accountId,
                    userAction: ""
                )
            )
            ToastManager.shared.show("Card deleted.", style: .success, position: .bottom)
            dismiss()
            onDeleted()
        } catch {
            ToastManager.shared.show("Failed to delete card.", style: .error, position: .bottom)
        }
        isDeleting = false
    }
}
