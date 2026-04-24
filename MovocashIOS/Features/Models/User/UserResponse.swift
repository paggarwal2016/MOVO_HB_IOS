//
//  UserResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 18/03/26.
//

import Foundation

nonisolated struct UserProfileAPIResponse: Decodable, Sendable {
    let success: Bool
    let data: UserProfileResponse
}

nonisolated struct UserProfileResponse: Decodable, Sendable {

    // MARK: - Always present
    let customerId: Int
    let username: String

    // MARK: - Possibly missing or empty in real response
    let firstName: String?
    let lastName: String?
    let dob: String?
    let email: String?
    let phone: String?
    let profilePicture: String?

    // MARK: - Address (all empty strings in your response)
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let state: String?
    let zip: String?

    // MARK: - ID verification (missing in your real response)
    let driversLicenseNumber: String?
    let driversLicenseState: String?
    let driversLicenseExpiration: String?

    // MARK: - Flags
    let isTwoFactorEnabled: Bool
    let emailVerified: Bool
    let emailVerifiedDate: String?
    let smsVerified: Bool
    let smsVerifiedDate: String?
    let isDeactivated: Bool
    let isAdditionalKycRequired: Bool
    let isPlaidAuthRequired: Bool
    let cipRequired: Bool
    let cipAllowed: Bool

    // MARK: - Dates (missing in your real response)
    let tosAcceptedDate: String?
    let eDeliveryAcceptedDate: String?
    let virtualCardTosAcceptedDate: String?
    let verificationToken: String?
    let verificationTokenExpiration: String?

    // MARK: - Computed helpers for the UI

    var fullName: String {
        let f = firstName?.trimmingCharacters(in: .whitespaces) ?? ""
        let l = lastName?.trimmingCharacters(in: .whitespaces) ?? ""
        if f.isEmpty && l.isEmpty { return "—" }
        return "\(f) \(l)".trimmingCharacters(in: .whitespaces)
    }

    var initials: String {
        let f = firstName?.prefix(1).uppercased() ?? ""
        let l = lastName?.prefix(1).uppercased() ?? ""
        let result = f + l
        return result.isEmpty ? "?" : result
    }

    var displayEmail: String    { email?.isEmpty == false ? email ?? "—" : "—" }
    var displayPhone: String    { phone?.isEmpty == false ? phone ?? "—" : "—" }
    var displayAddress: String? {
        guard let line1 = addressLine1, !line1.isEmpty else { return nil }
        return line1
    }
}
