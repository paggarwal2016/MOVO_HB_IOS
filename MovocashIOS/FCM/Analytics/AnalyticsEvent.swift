//
//  AnalyticsEvent.swift
//  MovocashIOS
//
//  Created by Movo Developer on 02/04/26.
//

import Foundation

// MARK: - Event Name Constants

enum AnalyticsEvent {

    // MARK: - General
    static let screenView            = "screen_view"

    // MARK: - Auth
    static let loginAttempt          = "login_attempt"
    static let loginSuccess          = "login_success"
    static let loginFailed           = "login_failed"
    static let logout                = "user_logout"
    static let sessionExpired        = "session_expired"
    static let tokenRefreshed        = "token_refreshed"

    // MARK: - Security
    static let biometricAuth         = "biometric_auth"
    static let biometricEnrolled     = "biometric_enrolled"
    static let biometricRevoked      = "biometric_revoked"
    static let suspiciousActivity    = "suspicious_activity_flagged"
    static let pinChanged            = "pin_changed"
    static let lockoutTriggered      = "lockout_triggered"
    static let lockoutPermanent      = "lockout_permanent"

    // MARK: - KYC
    static let kycStarted            = "kyc_started"
    static let kycStepFailed         = "kyc_step_failed"
    static let kycCompleted          = "kyc_completed"
    static let kycAbandoned          = "kyc_abandoned"

    // MARK: - Accounts / Balances
    static let accountViewed         = "account_viewed"
    static let accountDeleted        = "account_deleted"

    // MARK: - Savings Accounts
    static let savingsAccountListViewed   = "savings_account_list_viewed"
    static let savingsAccountDetailViewed = "savings_account_detail_viewed"
    static let savingsAccountCreated      = "savings_account_created"
    static let savingsAccountCreateFailed = "savings_account_create_failed"
    static let savingsNicknameUpdated     = "savings_nickname_updated"
    static let savingsAccountDeleted      = "savings_account_deleted"

    // MARK: - Rewards
    static let rewardViewed               = "reward_viewed"
    static let rewardFetchFailed          = "reward_fetch_failed"
    static let rewardRedeemed             = "reward_redeemed"
    static let rewardRedemptionFailed     = "reward_redemption_failed"
    static let rewardEnrolled             = "reward_enrolled"
    static let rewardEnrollFailed         = "reward_enroll_failed"

    // MARK: - Withdrawals / Transfers
    static let withdrawalInitiated        = "withdrawal_initiated"
    static let withdrawalFailed           = "withdrawal_failed"
    static let transactionListViewed      = "transaction_list_viewed"
    static let internalTransferInitiated  = "internal_transfer_initiated"
    static let internalTransferFailed     = "internal_transfer_failed"

    // MARK: - Contacts
    static let contactListViewed                = "contact_list_viewed"
    static let contactListFailed                = "contact_list_failed"
    static let contactFavoritedList             = "contact_favorite_list"
    static let contactFavoritedListFailed       = "contact_favorite_list_failed"
    static let contactAddFavorited              = "contact_favorite_add"
    static let contactAddFavoritedFailed        = "contact_favorite_add_failed"
    static let contactRemoveFavorite            = "contact_favorite_remove"
    static let contactRemoveFavoriteFailed      = "contact_favorite_remove_failed"
    static let contactFrequent                  = "contact_frequent"
    static let contactFrequentFailed            = "contact_frequent_failed"

    // MARK: - VCards
    static let vcardViewed                = "vcard_viewed"
    static let vcardFetchFailed           = "vcard_fetch_failed"
    static let vcardCreated               = "vcard_created"
    static let vcardCreateFailed          = "vcard_create_failed"

    // MARK: - Plaid Link
    static let plaidLinkStarted           = "plaid_link_started"
    static let plaidLinkSuccess           = "plaid_link_success"
    static let plaidLinkExited            = "plaid_link_exited"
    static let plaidLinkFailed            = "plaid_link_failed"

    // MARK: - Errors
    static let appError              = "app_error"
}

// MARK: - Event Parameter Keys

enum AnalyticsParam {
    static let screenName       = "screen_name"
    static let method           = "method"
    static let amount           = "amount"
    static let type             = "type"
    static let errorCode        = "error_code"
    static let kycStep          = "kyc_step"
    static let reason           = "reason"
    static let step             = "step"
    static let accountId        = "account_id"
    static let accountName      = "account_name"
    static let savingsAccountId = "savings_account_id"
    static let toAccountId      = "to_account_id"
    static let fromAccountId    = "from_account_id"
    static let count            = "count"
    static let contactId        = "contact_id"
    static let institutionName  = "institution_name"
    static let lockoutRound     = "lockout_round"
    static let lockoutDuration  = "lockout_duration"
}

// MARK: - User Property Values

enum AuthStatusValue {
    static let loggedIn  = "logged_in"
    static let loggedOut = "logged_out"
}

// MARK: - User Property Keys

enum UserPropertyKey {
    static let kycStatus            = "kyc_status"
    static let authStatus           = "auth_status"
    static let biometricEnabled     = "biometric_enabled"
}

// MARK: - Supporting Enums

enum KYCStep: String {
    case idVerified      = "id_verified"
    case bankLinked      = "bank_linked"
    case addressVerified = "address_verified"
    case selfieVerified  = "selfie_verified"
}

enum AuthMethod: String {
    case mpin      = "mpin"
    case biometric = "biometric"
    case otp       = "otp"
    case password  = "password"
}

