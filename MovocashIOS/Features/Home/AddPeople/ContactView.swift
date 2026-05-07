//
//  ContactView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/03/26.
//

import SwiftUI

struct ContactView: View {
    
    @Binding var isPresented: Bool
    @StateObject private var viewModel: ContactViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: AppContainer
    
    init(isPresented: Binding<Bool>, service: ContactsServiceProtocol = ContactsService(), network: NetworkServiceProtocol = NetworkService.shared) {
        _viewModel = StateObject(wrappedValue: ContactViewModel(service: service, network: network, alertManager: AlertManager.shared))
        _isPresented = isPresented
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                contentBody
            }
            .background(Color(.systemBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray6), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationDestination(for: ContactRecord.self) { contact in
                QuickTransferView(contact: contact, container: container)
            }
        }
        .task {
            await viewModel.load()
        }
    }
    
    @ViewBuilder
    private var contentBody: some View {
        if let error = viewModel.loadError {
            errorView(message: error)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch viewModel.state {
            case .loading:
                SpinnerView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                headerSection
                searchBar
                contactList
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.gray)
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            if viewModel.isPermissionError {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
                Text("You may need to reopen the app after granting access.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Send Money")
                .font(.system(size: 22, weight: .bold))
            Text("Select a recipient from your contacts")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search contacts", text: $viewModel.search)
                .autocorrectionDisabled()
            if !viewModel.search.isEmpty {
                Button { viewModel.search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 15))
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - Contact List
    
    private var contactList: some View {
        List {
            if !viewModel.filteredFavourites.isEmpty {
                Section {
                    ForEach(viewModel.filteredFavourites) { contact in
                        contactRow(contact)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                } header: {
                    sectionHeader("Favourites")
                }
            }

            if !viewModel.filteredContacts.isEmpty {
                Section {
                    ForEach(viewModel.filteredContacts) { contact in
                        contactRow(contact)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                } header: {
                    sectionHeader("All Contacts")
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.gray)
            .textCase(.uppercase)
            .tracking(0.6)
    }
    
    // MARK: - Contact Row

    private func contactRow(_ contact: ContactRecord) -> some View {
        let starred = viewModel.isFavorite(contact)
        return NavigationLink(value: contact) {
            HStack(spacing: 14) {
                contactAvatar(initials: contact.initials, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(contact.nickname ?? "")
                        .font(.system(size: 15, weight: .medium))
                    Text(contact.phoneNumber ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                Spacer()
                Button {
                    Task { await viewModel.toggleFavourite(contact) }
                } label: {
                    Image(systemName: starred ? "star.fill" : "star")
                        .font(.system(size: 18))
                        .foregroundColor(starred ? Color.primary : Color(.systemGray3))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Shared Avatar
    
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
}
