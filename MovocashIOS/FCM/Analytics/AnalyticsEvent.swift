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
    static let otpSent               = "otp_sent"
    static let otpSendFailed         = "otp_send_failed"

    // MARK: - Signup / Registration
    static let signupStarted         = "signup_started"
    static let signupPhoneSubmitted  = "signup_phone_submitted"
    static let signupEmailSubmitted  = "signup_email_submitted"
    static let signupEmailVerified   = "signup_email_verified"
    static let signupTermsAccepted   = "signup_terms_accepted"
    static let signupCompleted       = "signup_completed"

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
    static let kycSdkOpened          = "kyc_sdk_opened"
    static let kycSdkClosed          = "kyc_sdk_closed"

    // MARK: - Accounts / Balances
    static let accountViewed         = "account_viewed"
    static let accountDeleted        = "account_deleted"

    // MARK: - Savings Accounts
    static let savingsAccountListViewed   = "savings_account_list_viewed"
    static let savingsAccountDetailViewed = "savings_account_detail_viewed"
    static let savingsAccountListFailed   = "savings_account_list_failed"
    static let savingsAccountDetailFailed = "savings_account_detail_failed"
    static let savingsAccountCreated      = "savings_account_created"
    static let savingsAccountCreateFailed = "savings_account_create_failed"
    static let savingsNicknameUpdated     = "savings_nickname_updated"
    static let savingsNicknameUpdateFailed = "savings_nickname_update_failed"
    static let savingsAccountDeleted      = "savings_account_deleted"
    static let savingsAccountDeleteFailed = "savings_account_delete_failed"

    // MARK: - Rewards
    static let rewardViewed               = "reward_viewed"
    static let rewardFetchFailed          = "reward_fetch_failed"
    static let rewardRedeemed             = "reward_redeemed"
    static let rewardRedemptionFailed     = "reward_redemption_failed"
    static let rewardEnrolled             = "reward_enrolled"
    static let rewardEnrollFailed         = "reward_enroll_failed"

    // MARK: - Withdrawals / Transfers
    static let checkIntentFailed          = "check_intent_failed"
    static let withdrawalInitiated        = "withdrawal_initiated"
    static let withdrawalSuccess          = "withdrawal_success"
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
    static let contactReferralInvite            = "contact_referral_invite"
    static let contactReferralInviteFailed      = "contact_referral_invite_failed"
    static let contactCreated                   = "contact_created"
    static let contactCreateFailed              = "contact_create_failed"

    // MARK: - SMS Composer (MFMessageComposeViewController)
    static let smsComposerOpened                = "sms_composer_opened"
    static let smsComposerClosed                = "sms_composer_closed"

    // MARK: - Contact Picker (CNContactPickerViewController)
    static let contactPickerOpened              = "contact_picker_opened"
    static let contactPickerClosed              = "contact_picker_closed"

    // MARK: - VCards
    static let vcardViewed                = "vcard_viewed"
    static let vcardFetchFailed           = "vcard_fetch_failed"
    static let vcardCreated               = "vcard_created"
    static let vcardCreateFailed          = "vcard_create_failed"
    static let cardActivated              = "card_activated"
    static let cardActivationFailed       = "card_activation_failed"
    static let walletAdd                  = "wallet_add"
    static let walletAddFailed            = "wallet_add_failed"

    // MARK: - Plaid Link
    static let plaidLinkStarted           = "plaid_link_started"
    static let plaidLinkSuccess           = "plaid_link_success"
    static let plaidLinkExited            = "plaid_link_exited"
    static let plaidLinkFailed            = "plaid_link_failed"

    // MARK: - ACH / Funding
    static let achTransferInitiated       = "ach_transfer_initiated"
    static let achTransferFailed          = "ach_transfer_failed"
    static let achAccountsViewed          = "ach_accounts_viewed"
    static let achAccountsFetchFailed     = "ach_accounts_fetch_failed"

    // MARK: - Documents
    static let documentViewed             = "document_viewed"
    static let documentFetchFailed        = "document_fetch_failed"

    // MARK: - App Update / Version Gate (/app/check)
    static let appUpdateForced            = "app_update_forced"
    static let appUpdateOptional          = "app_update_optional"
    static let appMaintenance             = "app_maintenance"
    static let appUpdateCheckFailed       = "app_update_check_failed"
    static let appUpdateCtaTapped         = "app_update_cta_tapped"
    static let appMaintenanceRetry        = "app_maintenance_retry"

    // MARK: - Network
    /// Emitted once per completed HTTP request from the central network layer
    /// (success and failure). Carries endpoint, method, status, timing and a
    /// stable, PII-free error code so any user's failing call is traceable.
    static let apiCall               = "api_call"

    // MARK: - Errors
    static let appError              = "app_error"
}

// MARK: - Event Parameter Keys

enum AnalyticsParam {
    static let screenName       = "screen_name"
    static let method           = "method"
    static let amountRange      = "amount_range"
    static let type             = "type"
    static let errorCode        = "error_code"
    static let errorMessage     = "error_message"
    static let kycStep          = "kyc_step"
    static let reason           = "reason"
    static let step             = "step"
    static let accountId        = "account_id"
    static let savingsAccountId = "savings_account_id"
    static let toAccountId      = "to_account_id"
    static let fromAccountId    = "from_account_id"
    static let count            = "count"
    static let contactId        = "contact_id"
    static let institutionName  = "institution_name"
    static let lockoutRound     = "lockout_round"
    static let lockoutDuration  = "lockout_duration"
    static let endpoint         = "endpoint"
    static let httpMethod       = "http_method"
    static let statusCode       = "status_code"
    static let responseTime     = "response_time_ms"
    static let responseBucket   = "response_time_bucket"
    static let requestId        = "request_id"
    static let context          = "context"
    static let userAction       = "user_action"
    static let updateType       = "update_type"
    static let latestVersion    = "latest_version"
}

// MARK: - Value Bucketing

/// Coarse ranges for monetary values so analytics captures transaction-size
/// behaviour WITHOUT sending exact amounts (financial PII) to Firebase.
enum AnalyticsBucket {
    static func amount(_ value: Double) -> String {
        switch value {
        case ..<10:    return "lt_10"
        case ..<50:    return "10_50"
        case ..<100:   return "50_100"
        case ..<500:   return "100_500"
        case ..<1000:  return "500_1000"
        default:       return "gte_1000"
        }
    }

    /// Coarse latency ranges (milliseconds) so we can spot slow endpoints without
    /// storing exact per-request timings.
    static func responseTime(_ ms: Int) -> String {
        switch ms {
        case ..<200:   return "lt_200"
        case ..<500:   return "200_500"
        case ..<1000:  return "500_1000"
        case ..<3000:  return "1000_3000"
        default:       return "gte_3000"
        }
    }
}

// MARK: - Screen Names

/// Screen-view names passed to `trackScreen(_:)` / `View.trackScreen(_:)`.
/// Kept as constants so names stay consistent across the app.
enum AnalyticsScreen {
    // Onboarding / Auth
    static let choice            = "onboarding_choice"
    static let phoneLogin        = "onboarding_phone_login"
    static let phoneSignup       = "onboarding_phone_signup"
    static let otp               = "onboarding_otp"
    static let emailEntry        = "onboarding_email"
    static let emailVerification = "onboarding_email_verification"
    static let terms             = "onboarding_terms"
    static let kycDocument       = "kyc_document_pick"
    static let kycSuccess        = "kyc_success"
    static let waitlist          = "waitlist"

    // Main
    static let dashboard         = "dashboard"
    static let profile           = "profile"
    static let fundAccount       = "fund_account"
    static let payAnyone         = "pay_anyone"
    static let quickPay          = "quick_pay"
    static let internalTransfer  = "internal_transfer"
    static let document          = "document_view"
    static let transactionHistory = "transaction_history"
    static let cardDetail        = "card_detail"
    static let savingsDetail     = "savings_detail"
    static let addContact        = "add_contact"
    static let securitySettings  = "security_settings"
    static let rewardUnlock      = "reward_unlock"
    static let appUpdate         = "app_update_gate"
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

