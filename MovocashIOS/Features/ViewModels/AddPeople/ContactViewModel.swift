//
//  ContactViewModel.swift
//  MovocashIOS
//
//  Created by Vinu on 25/03/26.
//

import Foundation
import Combine

final class ContactViewModel: BaseViewModel {

    @Published var contacts: [AppContact] = []
    @Published var search = ""
    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var loadError: String? = nil

    private let service: ContactsServiceProtocol

    init(service: ContactsServiceProtocol, alertManager: AlertManagerProtocol) {
        self.service = service
        super.init(alertManager: alertManager)
    }

    var filtered: [AppContact] {
        search.isEmpty ? contacts :
        contacts.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var favoriteContacts: [AppContact] {
        contacts.filter { favorites.contains($0.id) }
    }

    // TODO: Favorite contact sync to backend — API call here
    func toggleFavorite(_ contact: AppContact) {
        if favorites.contains(contact.id) {
            favorites.remove(contact.id)
        } else {
            favorites.insert(contact.id)
        }
        // API call here after success need to validate the favorites value
    }

    func isFavorite(_ contact: AppContact) -> Bool {
        favorites.contains(contact.id)
    }

    func load() async {
        loadError = nil
        do {
            let result = try await perform { try await self.service.fetchContacts() }
            contacts = result
        } catch {
            loadError = error.localizedDescription
        }
    }
}
