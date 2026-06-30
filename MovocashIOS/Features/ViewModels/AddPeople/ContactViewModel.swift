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

    /// Validates the phone number (10 digits). Nickname is optional.
    var canSubmit: Bool {
        digits.count == 10
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
        // Nickname is optional; only the phone number is required.
        guard digits.count == 10 else { return nil }
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
        setupContactPipelines()
    }
    
    // MARK: - Cached Lists
    //
    // Cached (not computed) so dedup + phone-normalization runs only when the source
    // arrays change — off the main thread — and search is debounced. Typing no longer
    // re-runs the whole pipeline on every keystroke / re-render.

    /// API + device contacts, de-duped by phone, favourites removed.
    @Published private(set) var mergedContacts: [ContactRecord] = []
    /// `mergedContacts` filtered by the debounced `search`.
    @Published private(set) var filteredContacts: [ContactRecord] = []
    /// Favourites filtered by the debounced `search`.
    @Published private(set) var filteredFavourites: [ContactRecord] = []

    /// Device contacts available to import (Add Contact sheet), excluding numbers
    /// already added in the app. Appends newly-granted contacts as `contacts` reloads.
    @Published private(set) var importableContacts: [ContactRecord] = []
    /// `importableContacts` filtered by the debounced `importSearch`.
    @Published private(set) var filteredImportable: [ContactRecord] = []
    /// Search text for the Add Contact sheet's import list.
    @Published var importSearch = ""

    var favoriteContacts: [ContactRecord] { favourites }

    /// Set of favourite IDs kept in sync with `favourites` so per-row favourite
    /// checks are O(1) instead of scanning the array for every contact row.
    @Published private(set) var favouriteIDs: Set<String> = []

    func isFavorite(_ contact: ContactRecord) -> Bool {
        favouriteIDs.contains(contact.id)
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

    /// Populates the sheet's nickname + phone fields from a tapped device contact.
    func fill(from contact: ContactRecord) {
        nickname = contact.nickname ?? ""
        phoneInput = Self.formatPhone(PhoneNumberValidator.sanitize(contact.phoneNumber ?? ""))
        helperIsError = false
    }

    // MARK: - List computation (pure, runs off the main thread)

    /// Normalized phone key ("+1XXXXXXXXXX") used for duplicate matching.
    nonisolated private static func normalizedKey(_ phone: String?) -> String? {
        guard let phone, !phone.isEmpty else { return nil }
        let sanitized = PhoneNumberValidator.sanitize(phone)
        guard !sanitized.isEmpty else { return nil }
        return PhoneNumberValidator.normalize(sanitized)
    }

    nonisolated private static func computeMerged(api: [ContactRecord], device: [ContactRecord], favourites: [ContactRecord]) -> [ContactRecord] {
        let favIds = Set(favourites.map(\.id))
        var seen = Set<String>()
        return (api + device)
            .filter { !favIds.contains($0.id) }
            .filter { contact in
                guard let phone = contact.phoneNumber, !phone.isEmpty else { return true }
                return seen.insert(phone).inserted
            }
            .sorted { $0.isAdded && !$1.isAdded }
    }

    nonisolated private static func computeImportable(device: [ContactRecord], api: [ContactRecord]) -> [ContactRecord] {
        let existing = Set(api.compactMap { normalizedKey($0.phoneNumber) })
        var seen = Set<String>()
        return device.filter { contact in
            guard let key = normalizedKey(contact.phoneNumber) else { return false }
            guard !existing.contains(key) else { return false }
            return seen.insert(key).inserted
        }
    }

    nonisolated private static func applySearch(_ list: [ContactRecord], query: String) -> [ContactRecord] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return list }
        return list.filter {
            ($0.nickname ?? "").localizedCaseInsensitiveContains(q) ||
            ($0.phoneNumber ?? "").contains(q)
        }
    }

    // MARK: - Reactive pipelines (cache + debounce + off-main filtering)

    private func setupContactPipelines() {
        let work = DispatchQueue.global(qos: .userInitiated)

        // Keep the O(1) favourite-ID lookup set in sync with the favourites array.
        $favourites
            .map { Set($0.map(\.id)) }
            .assign(to: &$favouriteIDs)

        // Heavy lists recompute only when their source arrays change.
        Publishers.CombineLatest3($apiContacts, $contacts, $favourites)
            .receive(on: work)
            .map { Self.computeMerged(api: $0, device: $1, favourites: $2) }
            .receive(on: DispatchQueue.main)
            .assign(to: &$mergedContacts)

        Publishers.CombineLatest($contacts, $apiContacts)
            .receive(on: work)
            .map { Self.computeImportable(device: $0, api: $1) }
            .receive(on: DispatchQueue.main)
            .assign(to: &$importableContacts)

        // Debounced search queries (prepend the current value so the list shows
        // immediately rather than after the first 300ms).
        let mainQuery = $search
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .prepend(search)
            .removeDuplicates()

        let importQuery = $importSearch
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .prepend(importSearch)
            .removeDuplicates()

        Publishers.CombineLatest($mergedContacts, mainQuery)
            .receive(on: work)
            .map { Self.applySearch($0, query: $1) }
            .receive(on: DispatchQueue.main)
            .assign(to: &$filteredContacts)

        Publishers.CombineLatest($favourites, mainQuery)
            .receive(on: work)
            .map { favs, query -> [ContactRecord] in
                // Drop favourites whose number isn't a valid US (NANP) number.
                let valid = favs.filter { $0.hasValidPhone }
                let sorted = valid.sorted { $0.isAdded && !$1.isAdded }
                return Self.applySearch(sorted, query: query)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$filteredFavourites)

        Publishers.CombineLatest($importableContacts, importQuery)
            .receive(on: work)
            .map { Self.applySearch($0, query: $1) }
            .receive(on: DispatchQueue.main)
            .assign(to: &$filteredImportable)
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
    
    /// Loads recent (frequent) contacts. Returns `true` on success (or cancellation,
    /// which is not a user-facing failure) and `false` when the request errors, so
    /// callers can present an error state. `@discardableResult` keeps existing callers
    /// that ignore the outcome unaffected.
    @discardableResult
    func loadFrequent() async -> Bool {
        do {
            let response: RecentTransferResponse = try await perform {
                try await self.network.request(ContactAPI.getRecent)
            }
            // Drop frequents whose number isn't a valid US (NANP) number.
            frequents = response.contacts.filter { $0.hasValidPhone }
            analytics.log(AnalyticsEvent.contactFrequent, params: [
                AnalyticsParam.count: frequents.count
            ])
            return true
        } catch is CancellationError {
            return true
        } catch {
            analytics.log(AnalyticsEvent.contactFrequentFailed, params: [
                AnalyticsParam.errorCode: error.localizedDescription
            ])
            return false
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
    
    
    // MARK: - Add Favourite
    
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
    
    //MARK: - Remove Favourite
    
    private func removeFavourite(contactId: String) async {
        let request = ContactRequest.DeleteFavourite(contact_id: contactId,
                                                     userAction: "DELETE-CONTACT")
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
    
    //MARK: - Referral Invite

    /// People the user has already invited, fetched via GET-REFERRAL-LIST.
    @Published var referralInvitees: [ReferralInvitee] = []

    /// Loads the referral invite list (`ContactAPI.referrelInviteList`) into
    /// `referralInvitees`. Used by ShareInviteSheet to show the already-invited list.
    func loadReferralInvitees() async {
        do {
            let response: ReferralInviteListResponse = try await perform {
                try await self.network.request(ContactAPI.referrelInviteList)
            }
            referralInvitees = response.data
        } catch is CancellationError {
        } catch {
            SecureLogger.error("Referral list load failed: \(error.localizedDescription)", category: .network)
        }
    }

    /// Notifies the skinny processor that an invite was sent.
    /// - Returns: the server's success message (`nil` when empty or on failure) so
    ///   the caller can surface it instead of a hardcoded string.
    @discardableResult
    func inviteUser(phone: String, nickname: String? = nil) async -> String? {
        let request = ContactRequest.Referral(invitee_phone: phone,
                                              invitee_nickname: nickname,
                                              userAction: "REFERRAL-INVITE",
                                              relation: "FRI")
        do {
            let response: ContactActionResponse = try await perform {
                try await self.network.request(ContactAPI.referralInvite(request: request))
            }
            analytics.log(AnalyticsEvent.contactReferralInvite, params: [
                AnalyticsParam.referralPhone: phone
            ])
            return response.message.isEmpty ? nil : response.message
        } catch is CancellationError {
            return nil
        } catch {
            analytics.log(AnalyticsEvent.contactReferralInviteFailed, params: [
                AnalyticsParam.errorCode: error.localizedDescription
            ])
            return nil
        }
    }
}
