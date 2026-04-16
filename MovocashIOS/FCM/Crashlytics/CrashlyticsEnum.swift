//
//  CrashlyticsEnum.swift
//  MovocashIOS
//
//  Created by Vinu on 16/04/26.
//

import Foundation

// ─────────────────────────────────────────────────────────────
// MARK: - Error Domain Definitions
// ─────────────────────────────────────────────────────────────

/// High-level domains that group errors by feature area.
/// Keeps Crashlytics issues organized in the Firebase console.
enum ErrorDomain: String {
    case authentication = "auth"
    case payment = "payment"
    case kyc = "kyc"
    case network = "network"
    case dataSync = "data_sync"
    case biometrics = "biometrics"
    case onboarding = "onboarding"
    case general = "general"
}

/// Severity levels used to triage issues in the dashboard.
enum ErrorSeverity: String {
    case critical
    case high
    case medium
    case low
}


// ─────────────────────────────────────────────────────────────
// MARK: - FinancialFlow Enum
// ─────────────────────────────────────────────────────────────

/// Identifies the active fintech flow for crash context.
/// Extend this enum as your app grows.
enum FinancialFlow: String {
    case sendMoney        = "send_money"
    case requestMoney     = "request_money"
    case cardActivation   = "card_activation"
    case kycVerification  = "kyc_verification"
    case onboarding       = "onboarding"
    case login            = "login"
    case biometricSetup   = "biometric_setup"
    case statementExport  = "statement_export"
}
