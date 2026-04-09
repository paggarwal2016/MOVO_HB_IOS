//
//  ContactViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/03/26.
//

import Foundation
import Combine

final class ContactViewModel: BaseViewModel {

    @Published var contacts: [AppContact] = []
    @Published var search = ""
    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var loadError: String? = nil

    private let service: ContactsServiceProtocol
    private let analytics: AnalyticsTracking

    init(
        service: ContactsServiceProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking? = nil
    ) {
        self.service = service
        self.analytics = analytics ?? AnalyticsManager.shared
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
            analytics.log(AnalyticsEvent.contactUnfavorited, params: [
                AnalyticsParam.contactId: contact.id
            ])
        } else {
            favorites.insert(contact.id)
            analytics.log(AnalyticsEvent.contactFavorited, params: [
                AnalyticsParam.contactId: contact.id
            ])
        }
        // API call here after success need to validate the favorites value
    }

    func isFavorite(_ contact: AppContact) -> Bool {
        favorites.contains(contact.id)
    }

    var isPermissionError: Bool {
        loadError == ContactsError.permissionDenied.localizedDescription
    }

    func load() async {
        guard state != .loading else { return }
        loadError = nil
        do {
            let result = try await perform { try await self.service.fetchContacts() }
            contacts = result
            analytics.log(AnalyticsEvent.contactListViewed, params: [
                AnalyticsParam.count: result.count
            ])
        } catch {
            loadError = error.localizedDescription
            analytics.log(AnalyticsEvent.contactListFailed, params: [
                AnalyticsParam.errorCode: error.localizedDescription
            ])
        }
    }
}
