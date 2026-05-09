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
    let accounts: [SavingsAccountInfo]
    
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var search: String = ""
    @State private var selectedContact: ContactRecord? = nil
    
    private var showSearch: Bool { contactVM.frequents.count > 15 }
    
    private var filteredFrequents: [RecordContact] {
        guard !search.isEmpty else { return contactVM.frequents }
        return contactVM.frequents.filter {
            ($0.nickname ?? "").localizedCaseInsensitiveContains(search) ||
            ($0.phoneNumber ?? "").contains(search)
        }
    }
    
    var body: some View {
        ZStack {
            MovoBackground()
            
            VStack(spacing: 0) {
                navBar
                
                if showSearch {
                    searchBar
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.md)
                }
                
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
                            } label: {
                                frequentRow(contact)
                            }
                            .buttonStyle(.plain)
                            
                            if contact.id != filteredFrequents.last?.id {
                                Rectangle()
                                    .fill(Color.movo.elevated)
                                    .frame(height: Stroke.hairline)
                                    .padding(.horizontal, 14)
                            }
                        }
                        Spacer().frame(height: 10)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.movo.surface.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.movo.elevated, lineWidth: Stroke.hairline)
                            )
                    )
                    .padding(.horizontal, Spacing.lg)
                    
                    Spacer().frame(height: 80)
                }
            }
        }
        .background(Color.movo.background)
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .onAppear {
            Task { await contactVM.loadFrequent() }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedContact != nil },
            set: { if !$0 { selectedContact = nil } }
        )) {
            if let contact = selectedContact {
                QuickTransferView(contact: contact, container: container, accounts: accounts)
            }
        }
    }
    
    private var navBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.movo.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.movo.elevated, in: Circle())
            }
            .buttonStyle(.plain)
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
            .font(Typography.subtitle.font)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.movo.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.movo.elevated, lineWidth: Stroke.hairline)
                )
        )
    }
    
    private func frequentRow(_ contact: RecordContact) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.movo.elevated)
                Circle().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                Text(contact.nickname?.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.movo.textPrimary)
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(contact.nickname ?? "")
                    .font(Typography.bodyCompact.font)
                    .foregroundColor(Color.movo.textPrimary)
                    .lineLimit(1)
                Text(contact.phoneNumber ?? "")
                    .font(Typography.captionSmall.font)
                    .foregroundColor(Color.movo.textTertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.movo.textDisabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
    }
}

