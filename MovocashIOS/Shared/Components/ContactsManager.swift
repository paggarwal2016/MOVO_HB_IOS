//
//  ContactsManager.swift
//  MovocashIOS
//
//  Created by Vinu on 25/03/26.
//

import Foundation
@preconcurrency import Contacts
import SwiftUI

// MARK: - Protocol (the key to DI + testability)

protocol ContactsServiceProtocol {
    func fetchContacts() async throws -> [AppContact]
}

// MARK: - Model

struct AppContact: Identifiable, Hashable {
    let id: String
    let name: String
    let phone: String
    let initials: String
}

// MARK: - Real implementation (used in production)

final class ContactsService: ContactsServiceProtocol {
    func fetchContacts() async throws -> [AppContact] {
        let granted = try await CNContactStore().requestAccess(for: .contacts)
        guard granted else { throw ContactsError.permissionDenied }

        // Fast-fail if the task was already cancelled before we start work.
        try Task.checkCancellation()

        return try await Task.detached(priority: .userInitiated) {
            let store = CNContactStore()
            let keys = [CNContactIdentifierKey, CNContactGivenNameKey, CNContactFamilyNameKey,
                        CNContactPhoneNumbersKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var result: [AppContact] = []
            try store.enumerateContacts(with: request) { contact, _ in
                let name = "\(contact.givenName) \(contact.familyName)"
                    .trimmingCharacters(in: .whitespaces)
                let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
                let initials = "\(contact.givenName.prefix(1))\(contact.familyName.prefix(1))"
                guard !name.isEmpty else { return }
                result.append(AppContact(
                    id: contact.identifier,
                    name: name,
                    phone: phone,
                    initials: initials
                ))
            }
            return result.sorted { $0.name < $1.name }
        }.value
    }
}

// MARK: - Mock implementation (used in tests + previews)

final class MockContactsService: ContactsServiceProtocol {
    var shouldFail = false
    var mockContacts: [AppContact] = [
        AppContact(id: "1", name: "Alice Johnson", phone: "+1 555 001 0001", initials: "AJ"),
        AppContact(id: "2", name: "Bob Smith",     phone: "+1 555 001 0002", initials: "BS"),
        AppContact(id: "3", name: "Clara Lee",     phone: "+1 555 001 0003", initials: "CL")
    ]

    func fetchContacts() async throws -> [AppContact] {
        if shouldFail { throw ContactsError.permissionDenied }
        return mockContacts
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
