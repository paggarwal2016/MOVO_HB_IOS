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
    static let sessionStarted        = "session_started"

    // MARK: - Auth
    static let loginAttempt          = "login_attempt"
    static let loginSuccess          = "login_success"
    static let loginFailed           = "login_failed"
    static let signUp                = "sign_up"
    static let logout                = "user_logout"
    static let reLoginSuccess        = "re_login_success"  // ← added: token expiry re-login
    static let sessionExpired        = "session_expired"   // ← added: token expired event
    static let tokenRefreshed        = "token_refreshed"   // ← added: silent refresh tracking

    // MARK: - Security
    static let biometricAuth         = "biometric_auth"
    static let twoFATriggered        = "two_fa_triggered"
    static let twoFACompleted        = "two_fa_completed"
    static let suspiciousActivity    = "suspicious_activity_flagged"
    static let pinChanged            = "pin_changed"

    // MARK: - KYC
    static let kycStarted            = "kyc_started"
    static let kycStepCompleted      = "kyc_step_completed"
    static let kycStepFailed         = "kyc_step_failed"
    static let kycCompleted          = "kyc_completed"
    static let kycAbandoned          = "kyc_abandoned"
    static let kycResubmitted        = "kyc_resubmitted"

    // MARK: - Transactions / Payments
    static let transactionInitiated  = "transaction_initiated"
    static let transactionSuccess    = "transaction_success"
    static let transactionFailed     = "transaction_failed"

    static let paymentInitiated      = "payment_initiated"
    static let paymentSuccess        = "payment_success"
    static let paymentFailed         = "payment_failed"
    static let paymentCancelled      = "payment_cancelled"
    static let paymentRetried        = "payment_retried"

    // MARK: - Cards / Payment Methods
    static let cardAdded             = "card_added"
    static let paymentMethodAdded    = "payment_method_added"
    static let paymentMethodRemoved  = "payment_method_removed"

    // MARK: - Accounts / Balances
    static let accountViewed         = "account_viewed"
    static let accountDeleted        = "account_deleted"
    static let balanceChecked        = "balance_checked"
    static let statementViewed       = "statement_viewed"
    static let accountLinked         = "account_linked"

    // MARK: - Investments / Loans / Budget
    static let loanApplied           = "loan_applied"
    static let investmentMade        = "investment_made"
    static let budgetSet             = "budget_set"

    // MARK: - Engagement
    static let featureViewed         = "feature_viewed"
    static let offerTapped           = "offer_tapped"
    static let offerDismissed        = "offer_dismissed"
    static let searchPerformed       = "search_performed"
    static let notificationTapped    = "notification_tapped"
    static let deepLinkOpened        = "deep_link_opened"

    // MARK: - Errors
    static let appError              = "app_error"
    static let networkError          = "network_error"
    static let apiError              = "api_error"
}

// MARK: - Event Parameter Keys
// ← fixed: was missing entirely — raw strings were used in AnalyticsManager

enum AnalyticsParam {
    static let screenName       = "screen_name"
    static let method           = "method"
    static let currency         = "currency"
    static let amount           = "amount"
    static let transactionId    = "transaction_id"
    static let type             = "type"
    static let errorCode        = "error_code"
    static let kycStep          = "kyc_step"
    static let loanType         = "loan_type"
    static let assetClass       = "asset_class"
    static let reason           = "reason"
    static let step             = "step"
}

// MARK: - User Property Values

enum AuthStatusValue {
    static let loggedIn  = "logged_in"
    static let loggedOut = "logged_out"
}

// MARK: - User Property Keys

enum UserPropertyKey {
    static let accountTier          = "account_tier"
    static let kycStatus            = "kyc_status"
    static let authStatus           = "auth_status"        // ← added: track login/logout state
    static let preferredProduct     = "preferred_product"
    static let preferredPayment     = "preferred_payment_method"
    static let notificationsEnabled = "notifications_enabled"
    static let biometricEnabled     = "biometric_enabled"
    static let appVersion           = "app_version"
}

// MARK: - Supporting Enums

enum PaymentMethod: String {
    case upi        = "upi"
    case card       = "card"
    case neft       = "neft"
    case rtgs       = "rtgs"
    case imps       = "imps"
    case wallet     = "wallet"
    case netBanking = "net_banking"
}

enum PaymentFlow: String {
    case p2p        = "p2p"
    case merchant   = "merchant"
    case billPay    = "bill_pay"
    case recharge   = "recharge"
    case investment = "investment"
    case loanEMI    = "loan_emi"
}

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

