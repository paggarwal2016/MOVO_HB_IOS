//
//  ContactViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/03/26.
//

import Foundation
import Combine

@MainActor
final class ContactViewModel: BaseViewModel {

    // MARK: - Phone Contacts (device)

    @Published var contacts: [AppContact] = []
    @Published var search = ""
    @Published private(set) var loadError: String? = nil

    // MARK: - API Contacts

    @Published private(set) var apiContacts: [ContactRecord] = []
    @Published private(set) var favourites: [ContactRecord] = []

    // MARK: - Dependencies

    private let contactsService: ContactsServiceProtocol
    private let network: NetworkServiceProtocol
    private let analytics: AnalyticsTracking

    // MARK: - Init

    init(
        service: ContactsServiceProtocol,
        network: NetworkServiceProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking? = nil
    ) {
        self.contactsService = service
        self.network = network
        self.analytics = analytics ?? AnalyticsManager.shared
        super.init(alertManager: alertManager)
    }

    // MARK: - Computed (Phone Contacts)

    var filtered: [AppContact] {
        search.isEmpty ? contacts :
        contacts.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var favoriteContacts: [AppContact] {
        let favPhones = Set(favourites.map(\.phoneNumber))
        return contacts.filter { favPhones.contains($0.phone) }
    }

    func isFavorite(_ contact: AppContact) -> Bool {
        favourites.contains { $0.phoneNumber == contact.phone }
    }

    var isPermissionError: Bool {
        loadError == ContactsError.permissionDenied.localizedDescription
    }

    // MARK: - Load Phone Contacts

    func load() async {
        guard state != .loading else { return }
        loadError = nil
        do {
            let result = try await perform { try await self.contactsService.fetchContacts() }
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

    // MARK: - Load API Contacts

    func loadApiContacts() async {
        let request = ContactRequest.GetLists(responseFlag: "ALL", userAction: "GET_CONTACTS")
        do {
            let response: ContactListResponse = try await perform {
                try await self.network.request(ContactAPI.getContacts(request: request))
            }
            apiContacts = response.contacts
            analytics.log(AnalyticsEvent.contactListViewed, params: [
                AnalyticsParam.count: response.contacts.count
            ])
        } catch is CancellationError {
        } catch {
            analytics.log(AnalyticsEvent.contactListFailed, params: [
                AnalyticsParam.errorCode: error.localizedDescription
            ])
        }
    }

    // MARK: - Load Favourites

    func loadFavourites() async {
        let request = ContactRequest.GetLists(responseFlag: "FAV", userAction: "GET_FAVOURITES")
        do {
            let response: ContactListResponse = try await perform {
                try await self.network.request(ContactAPI.getFavourites(request: request))
            }
            favourites = response.contacts
        } catch is CancellationError {
        } catch {}
    }

    // MARK: - Create Contact

    @discardableResult
    func createContact(nickname: String, phoneNumber: String, isFav: Bool = false) async -> Bool {
        let request = ContactRequest.Create(
            nickname: nickname,
            phoneNumber: phoneNumber,
            is_fav: isFav,
            addNewContact: true,
            userAction: "CREATE_CONTACT"
        )
        do {
            let _: ContactActionResponse = try await perform {
                try await self.network.request(ContactAPI.create(request: request))
            }
            await loadApiContacts()
            return true
        } catch is CancellationError { return false }
        catch { return false }
    }

    // MARK: - Toggle Favourite

    func toggleFavourite(_ record: ContactRecord) async {
        if record.isFav {
            await removeFavourite(contactId: record.id)
        } else {
            await addFavourite(contactId: record.id)
        }
    }

    // MARK: - Mark Favourite (PATCH by id)

    func markFavourite(id: String, isFav: Bool) async {
        let request = ContactRequest.MarkFavourite(is_fav: isFav, userAction: "MARK_FAVOURITE")
        do {
            let _: ContactActionResponse = try await perform {
                try await self.network.request(ContactAPI.getFavourite(id: id, request: request))
            }
            await loadFavourites()
        } catch is CancellationError {
        } catch {}
    }

    // MARK: - Private

    private func addFavourite(contactId: String) async {
        let request = ContactRequest.AddFavourite(
            contact_id: contactId,
            is_fav: true,
            addNewContact: false,
            userAction: "ADD_FAVOURITE"
        )
        do {
            let _: ContactActionResponse = try await perform {
                try await self.network.request(ContactAPI.addFavourite(request: request))
            }
            analytics.log(AnalyticsEvent.contactFavorited, params: [
                AnalyticsParam.contactId: contactId
            ])
            await loadFavourites()
        } catch is CancellationError {
        } catch {
            analytics.log(AnalyticsEvent.contactListFailed, params: [
                AnalyticsParam.errorCode: error.localizedDescription
            ])
        }
    }

    private func removeFavourite(contactId: String) async {
        let request = ContactRequest.DeleteFavourite(
            favContacts: contactId,
            userAction: "DELETE_FAVOURITE"
        )
        do {
            let _: ContactActionResponse = try await perform {
                try await self.network.request(ContactAPI.deleteFavourite(request: request))
            }
            analytics.log(AnalyticsEvent.contactUnfavorited, params: [
                AnalyticsParam.contactId: contactId
            ])
            await loadFavourites()
        } catch is CancellationError {
        } catch {
            analytics.log(AnalyticsEvent.contactListFailed, params: [
                AnalyticsParam.errorCode: error.localizedDescription
            ])
        }
    }
}
