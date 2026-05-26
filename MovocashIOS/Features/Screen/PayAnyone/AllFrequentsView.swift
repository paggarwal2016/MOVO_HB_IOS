//
//  AllFrequentsView.swift
//  MovocashIOS
//
//  Created by Vinu on 09/05/26.
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
    
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var search: String = ""
    @State private var selectedContact: ContactRecord? = nil
    @State private var isNavigating: Bool = false
    @State private var isLoading: Bool = true
    
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

                    if isLoading {
                        Spacer()
                        SpinnerView()
                        Spacer()
                    } else {
                    searchBar
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.md)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(filteredFrequents) { contact in
                                Button {
                                    selectedContact = ContactRecord(
                                        id: contact.id,
                                        isFav: false,
                                        nickname: contact.nickname,
                                        createdAt: Date(),
                                        phoneNumber: contact.phoneNumber,
                                        isAdded: false,
                                        updatedAt: Date()
                                    )
                                    isNavigating = true
                                } label: {
                                    frequentRow(contact)
                                }
                                .buttonStyle(.plain)

                                if contact.id != filteredFrequents.last?.id {
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
                    } // end else
                }
            }
            .background(Color.movo.background)
            .navigationBarHidden(true)
            .onAppear {
                if contactVM.frequents.isEmpty {
                    Task {
                        await contactVM.loadFrequent()
                        isLoading = false
                    }
                } else {
                    isLoading = false
                }
            }
            .navigationDestination(isPresented: $isNavigating) {
                if let contact = selectedContact {
                    QuickTransferView(contact: contact, container: container, cards: cards, primaryLinkedCard: primaryLinkedCard, onSuccess: { onSuccess() })
                }
            }
        }
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
                Text(contact.nickname?.prefix(1).uppercased() ?? "?")
                    .textStyle(Typography.cardTitle)
                    .foregroundColor(Color.movo.textPrimary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.nickname ?? "")
                    .textStyle(Typography.bodyCompact)
                    .foregroundColor(Color.movo.textPrimary)
                    .lineLimit(1)
                Text(contact.phoneNumber ?? "")
                    .textStyle(Typography.caption)
                    .foregroundColor(Color.movo.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.movo.textDisabled)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 64)
        .contentShape(Rectangle())
    }
}

