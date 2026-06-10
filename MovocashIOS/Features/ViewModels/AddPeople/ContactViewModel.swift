//
//  ContactViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/03/26.
//

import Foundation
import Combine
import Contacts

@MainActor
final class ContactViewModel: BaseViewModel {

    // MARK: - Device Contacts

    @Published var contacts: [ContactRecord] = []
    @Published var search = ""
    @Published private(set) var loadError: String? = nil
    /// Current device-contacts permission, kept in sync via `refreshAuthorization()`.
    @Published var authorizationStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    
    // MARK: - API Contacts
    
    @Published private(set) var frequents: [RecordContact] = []
    @Published private(set) var apiContacts: [ContactRecord] = []
    @Published private(set) var favourites: [ContactRecord] = []
    
    // MARK: - Dependencies
    
    private let contactsService: ContactsServiceProtocol
    private let network: NetworkServiceProtocol
    private let analytics: AnalyticsTracking
    
    // MARK: - Sheet
    
    @Published var nickname: String = ""
    @Published var phoneInput: String = "" // formatted for display, e.g. "(555) 123-4567"
    @Published var helperIsError: Bool = false
    
    /// Digits-only national number extracted from `phoneInput`.
    private var digits: String {
        phoneInput.filter(\.isNumber)
    }

    /// Validates that nickname is present and phone has 10 digits.
    var canSubmit: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty
            && digits.count == 10
    }

    var helperMessage: String {
        if helperIsError && digits.count != 10 {
            return "Enter a valid 10-digit phone number."
        }
        return ""
    }
    
    func clear() {
        nickname = ""
        phoneInput = ""
        helperIsError = false
    }
    
    func buildResult(countryCode: String) -> AddContactSheet.Result? {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespaces)
        guard !trimmedNickname.isEmpty, digits.count == 10 else { return nil }
        let e164 = "\(countryCode)\(digits)"
        return .init(
            nickname: trimmedNickname,
            phoneE164: e164,
            countryCode: countryCode,
            nationalNumber: digits
        )
    }

    /// Formats raw user input into `(XXX) XXX-XXXX` US phone-style as they type.
    /// Stops formatting at 10 digits.
    static func formatPhone(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber).prefix(10)
        var result = ""
        for (idx, ch) in digits.enumerated() {
            switch idx {
            case 0:  result += "(\(ch)"
            case 3:  result += ") \(ch)"
            case 6:  result += "-\(ch)"
            default: result.append(ch)
            }
        }
        return result
    }
    
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
    
    // MARK: - Computed
    
    var mergedContacts: [ContactRecord] {
        let favIds = Set(favourites.map(\.id))
        var seen = Set<String>()
        return (apiContacts + contacts)
            .filter { !favIds.contains($0.id) }
            .filter { contact in
                guard let phone = contact.phoneNumber, !phone.isEmpty else { return true }
                return seen.insert(phone).inserted
            }
            .sorted { $0.isAdded && !$1.isAdded }
    }
    
    var filteredContacts: [ContactRecord] {
        guard !search.isEmpty else { return mergedContacts }
        return mergedContacts.filter {
            ($0.nickname ?? "").localizedCaseInsensitiveContains(search) ||
            ($0.phoneNumber ?? "").contains(search)
        }
    }
    
    var filteredFavourites: [ContactRecord] {
        let sorted = favourites.sorted { $0.isAdded && !$1.isAdded }
        guard !search.isEmpty else { return sorted }
        return sorted.filter {
            ($0.nickname ?? "").localizedCaseInsensitiveContains(search) ||
            ($0.phoneNumber ?? "").contains(search)
        }
    }

    var favoriteContacts: [ContactRecord] { favourites }
    
    func isFavorite(_ contact: ContactRecord) -> Bool {
        favourites.contains { $0.id == contact.id }
    }
    
    var isPermissionError: Bool {
        loadError == ContactsError.permissionDenied.localizedDescription
    }

    // MARK: - Device Contact Import (Add Contact sheet)

    /// Permission tiers the Add Contact sheet branches on.
    enum ContactAccess { case undetermined, denied, limited, full }

    var contactAccess: ContactAccess {
        switch authorizationStatus {
        case .notDetermined:        return .undetermined
        case .authorized:           return .full
        case .restricted, .denied:  return .denied
        default:
            if #available(iOS 18.0, *), authorizationStatus == .limited { return .limited }
            return .denied
        }
    }

    /// Normalized phone key ("+1XXXXXXXXXX") used for duplicate matching.
    private func normalizedKey(_ phone: String?) -> String? {
        guard let phone, !phone.isEmpty else { return nil }
        let sanitized = PhoneNumberValidator.sanitize(phone)
        guard !sanitized.isEmpty else { return nil }
        return PhoneNumberValidator.normalize(sanitized)
    }

    /// Device contacts available to import: those with a phone number, excluding
    /// numbers already added in the app (matched by normalized phone), de-duped
    /// within the device list. New contacts granted later append automatically as
    /// `contacts` reloads.
    var importableContacts: [ContactRecord] {
        let existing = Set(apiContacts.compactMap { normalizedKey($0.phoneNumber) })
        var seen = Set<String>()
        return contacts.filter { contact in
            guard let key = normalizedKey(contact.phoneNumber) else { return false }
            guard !existing.contains(key) else { return false }
            return seen.insert(key).inserted
        }
    }

    func importableContacts(matching query: String) -> [ContactRecord] {
        let base = importableContacts
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return base }
        return base.filter {
            ($0.nickname ?? "").localizedCaseInsensitiveContains(trimmed) ||
            ($0.phoneNumber ?? "").contains(trimmed)
        }
    }

    /// Populates the sheet's nickname + phone fields from a tapped device contact.
    func fill(from contact: ContactRecord) {
        nickname = contact.nickname ?? ""
        phoneInput = Self.formatPhone(PhoneNumberValidator.sanitize(contact.phoneNumber ?? ""))
        helperIsError = false
    }

    /// Re-reads the live authorization status (call on appear / scene-active).
    func refreshAuthorization() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    /// First-time request: shows the system prompt when undetermined, then loads
    /// contacts if access (full or limited) was granted.
    func requestContactAccess() async {
        if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
            _ = try? await CNContactStore().requestAccess(for: .contacts)
        }
        refreshAuthorization()
        if contactAccess == .full || contactAccess == .limited {
            await load()
        }
    }

    // MARK: - Load Device Contacts
    
    func load() async {
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
        let request = ContactRequest.GetLists(responseFlag: "getnewContact", userAction: "GET_CONTACTS")
        do {
            let response: ContactListResponse = try await perform {
                try await self.network.request(ContactAPI.getContacts(request: request))
            }
            apiContacts = response.data.contacts
            analytics.log(AnalyticsEvent.contactListViewed, params: [
                AnalyticsParam.count: response.data.contacts.count
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
        let request = ContactRequest.GetLists(responseFlag: "getFavContact",
                                              userAction: "GET_FAVOURITES")
        do {
            let response: ContactListResponse = try await perform {
                try await self.network.request(ContactAPI.getFavourites(request: request))
            }
            favourites = response.data.contacts
            analytics.log(AnalyticsEvent.contactFavoritedList, params: [
                AnalyticsParam.count: response.data.contacts.count
            ])
        } catch is CancellationError {
        } catch {
            analytics.log(AnalyticsEvent.contactFavoritedListFailed, params: [
                AnalyticsParam.errorCode: error.localizedDescription
            ])
        }
    }
    
    
    // MARK: - Load Frequent
    
    func loadFrequent() async {
        do {
            let response: RecentTransferResponse = try await perform {
                try await self.network.request(ContactAPI.getRecent)
            }
            frequents = response.contacts
            analytics.log(AnalyticsEvent.contactFrequent, params: [
                AnalyticsParam.count: response.contacts.count
            ])
        } catch is CancellationError {
        } catch {
            analytics.log(AnalyticsEvent.contactFrequentFailed, params: [
                AnalyticsParam.errorCode: error.localizedDescription
            ])
        }
    }
    
    
    // MARK: - Create Contact
    
    @discardableResult
    func createContact(nickname: String, phoneNumber: String) async -> Bool {
        let normalizedPhone = phoneNumber.hasPrefix("+1") ? phoneNumber : "+1\(phoneNumber.filter(\.isNumber))"
        let request = ContactRequest.Create(
            nickname: nickname,
            phoneNumber: normalizedPhone,
            is_fav: false,
            addNewContact: true,
            userAction: "ADD-NEW-CONTACT"
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
        let existsInApi = apiContacts.contains { $0.id == record.id } ||
                          favourites.contains  { $0.id == record.id }
        if existsInApi {
            await markFavourite(id: record.id, isFav: !isFavorite(record))
        } else {
            let rawPhone = (record.phoneNumber ?? "").filter { $0.isNumber }
            let formattedPhone = rawPhone.hasPrefix("1") ? "+\(rawPhone)" : "+1\(rawPhone)"
            await addFavourite(contactId: record.id, nickname: record.nickname ?? "", phoneNumber: formattedPhone)
        }
        await loadApiContacts()
        await loadFavourites()
    }
    
    
    // MARK: - Mark Favourite (PATCH by id)
    
    func markFavourite(id: String, isFav: Bool) async {
        let request = ContactRequest.MarkFavourite(is_fav: isFav, userAction: "ADD_FAVOURITE")
        do {
            let _: ContactActionResponse = try await perform {
                try await self.network.request(ContactAPI.makeFavourite(id: id, request: request))
            }
            if isFav {
                if let contact = mergedContacts.first(where: { $0.id == id }) {
                    favourites.append(contact)
                }
            } else {
                favourites.removeAll { $0.id == id }
            }
        } catch is CancellationError {
        } catch {}
    }
    
    
    // MARK: - Private
    
    private func addFavourite(contactId: String, nickname: String, phoneNumber: String) async {
        let request = ContactRequest.AddFavourite(
            contact_id: contactId,
            is_fav: true,
            nickname: nickname,
            phoneNumber: phoneNumber,
            userAction: "ADD-CONTACT"
        )
        do {
            let _: ContactActionResponse = try await perform {
                try await self.network.request(ContactAPI.addFavourite(request: request))
            }
            analytics.log(AnalyticsEvent.contactAddFavorited, params: [
                AnalyticsParam.contactId: contactId
            ])
            if let contact = mergedContacts.first(where: { $0.id == contactId }) {
                favourites.append(contact)
            }
        } catch is CancellationError {
        } catch {
            analytics.log(AnalyticsEvent.contactAddFavoritedFailed, params: [
                AnalyticsParam.errorCode: error.localizedDescription
            ])
        }
    }
    
    
    private func removeFavourite(contactId: String) async {
        let request = ContactRequest.DeleteFavourite(
            contact_id: contactId,
            userAction: "DELETE-CONTACT"
        )
        do {
            let _: ContactActionResponse = try await perform {
                try await self.network.request(ContactAPI.deleteFavourite(request: request))
            }
            analytics.log(AnalyticsEvent.contactRemoveFavorite, params: [
                AnalyticsParam.contactId: contactId
            ])
            favourites.removeAll { $0.id == contactId }
        } catch is CancellationError {
        } catch {
            analytics.log(AnalyticsEvent.contactRemoveFavoriteFailed, params: [
                AnalyticsParam.errorCode: error.localizedDescription
            ])
        }
    }
}
