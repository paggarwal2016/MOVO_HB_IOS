//
//  UserRequest.swift
//  MovocashIOS
//
//  Created by Vinu on 28/04/26.
//

import Foundation

struct SaveUserRequest: Encodable {
    let customerId: Int
    let firstName: String
    let lastName: String
    let username: String
    let email: String
    let phone: String
    let addressLine1: String
    let addressLine2: String
    let city: String
    let state: String
    let zip: String
    let driversLicenseNumber: String
    let driversLicenseExpiration: String
    let driversLicenseState: String
    let profilePicture: String
    let isDeactivated: Bool
    let smsVerified: Bool
    let smsVerifiedDate: String?
    let emailVerified: Bool
    let emailVerifiedDate: String?
    let cipAllowed: Bool
    let cipRequired: Bool
    let isAdditionalKycRequired: Bool
    let isPlaidAuthRequired: Bool
    let isTwoFactorEnabled: Bool
    let tosAcceptedDate: String?
    let virtualCardTosAcceptedDate: String?
    let eDeliveryAcceptedDate: String?
    let fcmToken: String
    let userAction: String
}
