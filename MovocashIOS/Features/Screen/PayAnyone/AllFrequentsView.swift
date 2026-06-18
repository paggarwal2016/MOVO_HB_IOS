//
//  AllFrequentsView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 09/05/26.
//

import Foundation
import SwiftUI
import Combine

struct AllFrequentsView: View {
    @ObservedObject var contactVM: ContactViewModel
    let container: AppContainer
    let cards: [VCardListResponse]
    var primaryLinkedCard: VCardListResponse? = nil
    var onSuccess: () -> Void = {}
    
    @StateObject private var payeeFlow: PayeeTransferModel
    @ObservedObject private var primaryCardStore: PrimaryCardStore
    private var effectivePrimary: VCardListResponse? { primaryCardStore.card ?? primaryLinkedCard }

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var search: String = ""
    @State private var isLoading: Bool = true
    /// Set when the frequents API fails; shows a centered error in the content area.
    @State private var errorMessage: String? = nil
    
    init(contactVM: ContactViewModel, container: AppContainer, cards: [VCardListResponse], primaryLinkedCard: VCardListResponse? = nil, onSuccess: @escaping () -> Void = {}) {
        _contactVM = ObservedObject(wrappedValue: contactVM)
        self.container = container
        self.cards = cards
        self.primaryLinkedCard = primaryLinkedCard
        self.onSuccess = onSuccess
        _payeeFlow = StateObject(wrappedValue: PayeeTransferModel(container: container))
        _primaryCardStore = ObservedObject(wrappedValue: container.primaryCardStore)
        _isLoading = State(initialValue: contactVM.frequents.isEmpty)
    }
    
    private var showSearch: Bool { contactVM.frequents.count > 15 }
    
    private var filteredFrequents: [RecordContact] {
        guard !search.isEmpty else { return contactVM.frequents }
        return contactVM.frequents.filter {
            ($0.nickname ?? "").localizedCaseInsensitiveContains(search) ||
            ($0.phoneNumber ?? "").contains(search)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MovoBackground()
                VStack(spacing: 0) {
                    navBar
                    ZStack {
                        if let errorMessage {
                            errorView(errorMessage)
                        } else if !isLoading {
                            frequentsList
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                StatusBarScrim()
            }
            .background(Color.movo.background)
            // Full-screen spinner overlay — covers the whole view while loading.
            .overlay {
                if isLoading {
                    SpinnerView()
                }
            }
            .navigationBarHidden(true)
            .onAppear { load() }
            .payeeTransferFlow(payeeFlow, container: container, cards: cards, primaryLinkedCard: effectivePrimary, onSuccess: {
                onSuccess()
                // Silently refresh the frequents list after a successful transfer.
                Task { await contactVM.loadFrequent() }
            })
        }
    }
    
    // MARK: - Load

    /// Loads frequents (when not already cached), dismissing the spinner on success or
    /// failure. On failure a centered error is shown while the nav bar stays available.
    private func load() {
        guard contactVM.frequents.isEmpty else {
            isLoading = false
            return
        }
        Task {
            isLoading = true
            errorMessage = nil
            let ok = await contactVM.loadFrequent()
            isLoading = false
            if !ok {
                errorMessage = "Couldn't load recent contacts.\nPlease try again."
            }
        }
    }

    // MARK: - Content

    private var frequentsList: some View {
        // Compute the filtered list once per render (not per row) — the previous
        // `filteredFrequents.last?.id` inside the loop re-ran the filter for every row.
        let items = filteredFrequents
        return VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.md)

            ScrollView(showsIndicators: false) {
                // Lazy rendering so only on-screen rows are built.
                LazyVStack(spacing: 0) {
                    ForEach(items) { contact in
                        Button {
                            payeeFlow.tap(ContactRecord(
                                id: contact.id,
                                isFav: false,
                                nickname: contact.nickname,
                                createdAt: Date(),
                                phoneNumber: contact.phoneNumber,
                                isAdded: false,
                                updatedAt: Date()
                            ))
                        } label: {
                            frequentRow(contact)
                        }
                        .buttonStyle(.plain)

                        if contact.id != items.last?.id {
                            Rectangle()
                                .fill(Color.movo.border)
                                .frame(height: Stroke.hairline)
                                .padding(.horizontal, 14)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .fill(Color.movo.surface.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.heroCard)
                                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                        )
                )
                .padding(.horizontal, Spacing.lg)

                Spacer().frame(height: 80)
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .regular))
                .foregroundColor(Color.movo.textTertiary)
            Text(message)
                .textStyle(Typography.body)
                .foregroundColor(Color.movo.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var navBar: some View {
        HStack {
            CircularNavButton(systemName: "chevron.left") { dismiss() }
            Spacer()
            Text("Recent Pay")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg - 2)
        .padding(.bottom, Spacing.md)
    }
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.movo.textDisabled)
            TextField("", text: $search,
                      prompt: Text("Search contacts").foregroundColor(Color.movo.textDisabled))
            .textStyle(Typography.body)
            .foregroundColor(Color.movo.textPrimary)
            .autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.movo.textDisabled)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.movo.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
        )
    }
    
    private func frequentRow(_ contact: RecordContact) -> some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            ZStack {
                Circle().fill(Color.movo.elevated)
                Circle().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                Text(contact.avatarInitial)
                    .textStyle(Typography.cardTitle)
                    .foregroundColor(Color.movo.textPrimary)
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 3) {
                // Nickname when present; otherwise the phone number stands in.
                Text(contact.displayName)
                    .textStyle(Typography.bodyCompact)
                    .foregroundColor(Color.movo.textPrimary)
                    .lineLimit(1)
                // Secondary phone line is redundant when the primary already shows it.
                if contact.hasNickname {
                    Text(contact.phoneNumber ?? "")
                        .textStyle(Typography.caption)
                        .foregroundColor(Color.movo.textTertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            MovoChevron(.disclosure, color: Color.movo.textDisabled)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 64)
        .contentShape(Rectangle())
    }
}

