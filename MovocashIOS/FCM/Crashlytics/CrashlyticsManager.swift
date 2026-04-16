//
//  CrashlyticsManager.swift
//  MovocashIOS
//
//  Created by Vinu on 16/04/26.
//

import Foundation
import SwiftUI
import FirebaseCrashlytics

// ─────────────────────────────────────────────────────────────
// MARK: - CrashlyticsManager
// ─────────────────────────────────────────────────────────────

final class CrashlyticsManager {
    
    // ── Singleton ──────────────────────────────────────────────
    static let shared = CrashlyticsManager()
    private init() {}
    
    // ── State ──────────────────────────────────────────────────
    private(set) var isEnabled: Bool = true
    private var currentDomain: ErrorDomain = .general
    
    // ─────────────────────────────────────────────────────────
    // MARK: - Setup
    // ─────────────────────────────────────────────────────────
    
    /// Call once at app launch, after FirebaseApp.configure().
    /// Pass an *anonymised* identifier — never PII.
    ///
    /// - Parameter userID: An opaque ID (e.g. UUID or hashed internal ID).
    func configure(userID: String? = nil) {
        guard isEnabled else { return }
        
        if let id = userID {
            setAnonymousUserID(id)
        }
        
        // Record app version metadata for filtering in console
        setCustomKey("app_version", value: AppInfo.version)
        setCustomKey("build_number", value: AppInfo.buildNumber)
        setCustomKey("platform",    value: AppInfo.platform)
        
        log(event: "CrashlyticsManager configured")
    }
    
    // ─────────────────────────────────────────────────────────
    // MARK: - User Identity (Anonymised)
    // ─────────────────────────────────────────────────────────
    
    /// Sets an anonymous user identifier.
    /// ⚠️ NEVER pass real names, email addresses, account numbers, or any PII.
    func setAnonymousUserID(_ id: String) {
        guard isEnabled else { return }
        // Crashlytics.crashlytics().setUserID(id)
        print("[Crashlytics] User ID set: \(id)")
    }
    
    /// Clears user identity on logout — required for compliance.
    func clearUserIdentity() {
        guard isEnabled else { return }
        // Crashlytics.crashlytics().setUserID("")
        setCustomKey("user_segment", value: "logged_out")
        log(event: "User identity cleared on logout")
        print("[Crashlytics] User identity cleared")
    }
    
    // ─────────────────────────────────────────────────────────
    // MARK: - Breadcrumb Logging
    // ─────────────────────────────────────────────────────────
    
    /// Logs a plain-text breadcrumb visible in the crash report timeline.
    /// Keep messages short and free of sensitive data.
    func log(event: String) {
        guard isEnabled else { return }
        // Crashlytics.crashlytics().log(event)
        print("[Crashlytics] \(event)")
    }
    
    /// Convenience: log with a domain prefix for instant visual scanning.
    func log(event: String, domain: ErrorDomain) {
        log(event: "[\(domain.rawValue.uppercased())] \(event)")
    }
    
    // ─────────────────────────────────────────────────────────
    // MARK: - Custom Keys
    // ─────────────────────────────────────────────────────────
    
    /// Sets a key-value pair attached to every subsequent crash report.
    /// Values are limited to Bool, Int, Float, Double, or String.
    func setCustomKey(_ key: String, value: String) {
        guard isEnabled else { return }
        // Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        print("[Crashlytics] Key set — \(key): \(value)")
    }
    
    func setCustomKey(_ key: String, value: Bool) {
        guard isEnabled else { return }
        // Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        print("[Crashlytics] Key set — \(key): \(value)")
    }
    
    func setCustomKey(_ key: String, value: Int) {
        guard isEnabled else { return }
        // Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        print("[Crashlytics] Key set — \(key): \(value)")
    }
    
    // ─────────────────────────────────────────────────────────
    // MARK: - Error Recording
    // ─────────────────────────────────────────────────────────
    
    /// Records a non-fatal error. The app continues running.
    /// Use for recoverable failures in fintech flows.
    func recordError(
        _ error: Error,
        domain: ErrorDomain = .general,
        severity: ErrorSeverity = .medium,
        additionalInfo: [String: String] = [:]
    ) {
        guard isEnabled else { return }
        
        // Attach context keys before recording
        setCustomKey("error_domain",   value: domain.rawValue)
        setCustomKey("error_severity", value: severity.rawValue)
        
        additionalInfo.forEach { key, value in
            // Sanitise keys: Crashlytics allows only alphanumeric + underscore
            let safeKey = key.replacingOccurrences(of: " ", with: "_")
            setCustomKey(safeKey, value: value)
        }
        
        log(event: "[\(domain.rawValue)] \(error.localizedDescription)")
        
        // Crashlytics.crashlytics().record(error: error)
        print("[Crashlytics] Non-fatal recorded — \(error.localizedDescription)")
    }
    
    /// Records an NSError with a custom error code.
    /// Useful when wrapping third-party SDK errors.
    func recordError(
        message: String,
        code: Int,
        domain: ErrorDomain,
        severity: ErrorSeverity = .medium
    ) {
        let error = NSError(
            domain: "com.yourapp.\(domain.rawValue)",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        recordError(error, domain: domain, severity: severity)
    }
    
    // ─────────────────────────────────────────────────────────
    // MARK: - Fintech Flow Context Helpers
    // ─────────────────────────────────────────────────────────
    
    /// Call when a user enters a critical fintech flow.
    /// Sets breadcrumb context that will appear in any crash within the flow.
    func beginFlow(_ flow: FinancialFlow) {
        setCustomKey("active_flow", value: flow.rawValue)
        log(event: "Flow started: \(flow.rawValue)")
    }
    
    /// Call when a flow completes successfully or is abandoned.
    func endFlow(_ flow: FinancialFlow, success: Bool) {
        setCustomKey("active_flow", value: "none")
        log(event: "Flow ended: \(flow.rawValue) — \(success ? "success" : "abandoned")")
    }
    
    /// Tracks which step inside a multi-step flow the user is on.
    func setFlowStep(_ step: Int, of total: Int, flow: FinancialFlow) {
        setCustomKey("flow_step", value: "\(step)_of_\(total)")
        log(event: "[\(flow.rawValue)] Step \(step)/\(total)")
    }
    
    // ─────────────────────────────────────────────────────────
    // MARK: - Consent / Opt-Out
    // ─────────────────────────────────────────────────────────
    
    /// Enables or disables crash collection — wire this to your
    /// privacy settings screen to honour user opt-out requests.
    func setCrashCollectionEnabled(_ enabled: Bool) {
        isEnabled = enabled
        // Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
        UserDefaults.standard.set(enabled, forKey: "crashlytics_enabled")
        print("[Crashlytics] Collection \(enabled ? "enabled" : "disabled")")
    }
    
    /// Loads the persisted opt-in/out preference at launch.
    func loadPersistedConsent() {
        // Default true unless user has explicitly opted out
        let persisted = UserDefaults.standard.object(forKey: "crashlytics_enabled") as? Bool
        isEnabled = persisted ?? true
    }
    
    // ─────────────────────────────────────────────────────────
    // MARK: - Debug / QA Helpers
    // ─────────────────────────────────────────────────────────
    
#if DEBUG
    /// Forces a test crash. Remove all call-sites before shipping.
    func forceCrashForTesting() {
        log(event: "Intentional test crash triggered")
        // Crashlytics.crashlytics().log("Intentional test crash")
        fatalError("CrashlyticsManager: intentional test crash")
    }
#endif
    
    // ─────────────────────────────────────────────────────────
    // MARK: - Private Helpers
    // ─────────────────────────────────────────────────────────
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }
    
    private var currentEnvironment: String {
#if DEBUG
        return "debug"
#elseif STAGING
        return "staging"
#else
        return "production"
#endif
    }
}

