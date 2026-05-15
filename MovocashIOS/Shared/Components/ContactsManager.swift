//
//  ContactsManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/03/26.
//

import Foundation
@preconcurrency import Contacts
import SwiftUI

// MARK: - Protocol (the key to DI + testability)

protocol ContactsServiceProtocol {
    func fetchContacts() async throws -> [ContactRecord]
}

// MARK: - Real implementation (used in production)

final class ContactsService: ContactsServiceProtocol {
    func fetchContacts() async throws -> [ContactRecord] {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .notDetermined:
            let granted = try await store.requestAccess(for: .contacts)
            guard granted else { throw ContactsError.permissionDenied }
        case .denied, .restricted:
            throw ContactsError.permissionDenied
        case .authorized, .limited:
            break
        @unknown default:
            throw ContactsError.permissionDenied
        }

        // Fast-fail if the task was already cancelled before we start work.
        try Task.checkCancellation()

        return try await Task.detached(priority: .userInitiated) {
            let store = CNContactStore()
            let keys = [CNContactIdentifierKey, CNContactGivenNameKey, CNContactFamilyNameKey,
                        CNContactPhoneNumbersKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var result: [ContactRecord] = []
            try store.enumerateContacts(with: request) { contact, _ in
                let name = "\(contact.givenName) \(contact.familyName)"
                    .trimmingCharacters(in: .whitespaces)
                let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
                _ = "\(contact.givenName.prefix(1))\(contact.familyName.prefix(1))"
                guard !name.isEmpty else { return }
                result.append(ContactRecord(id: contact.identifier, isFav: false, nickname: name, createdAt: Date(), phoneNumber: phone, isAdded: false, updatedAt: Date()))
            }
            return result.sorted { $0.nickname ?? "" < $1.nickname ?? "" }
        }.value
    }
}


// MARK: - Error

enum ContactsError: LocalizedError {
    case permissionDenied
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Contacts access was denied."
        }
    }
}
