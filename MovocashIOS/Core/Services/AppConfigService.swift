//
//  AppConfigService.swift
//  MovocashIOS
//
//  Created by Movo Developer on 15/07/26.
//

import Foundation

// MARK: - Update Outcome

/// The launch-time decision derived from the remote app config and the installed
/// app version. Drives whether the app blocks, prompts, or proceeds.
enum AppUpdateOutcome: Equatable, Sendable {
    /// Installed version is supported and current — no action.
    case upToDate
    /// Shown as a dismissible prompt.
    case optionalUpdate(type: AppUpdateType, title: String, message: String, storeURL: URL?)
    /// Installed version is below the minimum (or the server forced an update).
    /// Shown as a non-dismissible block.
    case forceUpdate(type: AppUpdateType, title: String, message: String, storeURL: URL?)
    /// Backend is in maintenance — block with a maintenance title + message.
    case maintenance(title: String, message: String)
    /// True when the outcome must block all app interaction (non-dismissible).
    var isBlocking: Bool {
        switch self {
        case .forceUpdate, .maintenance: return true
        case .upToDate, .optionalUpdate: return false
        }
    }
    /// True for the soft, dismissible update prompt.
    var isOptionalUpdate: Bool {
        if case .optionalUpdate = self { return true }
        return false
    }
    
    var presentsGate: Bool { isBlocking || isOptionalUpdate }
}

// MARK: - Protocol

protocol AppConfigServiceProtocol: Sendable {
    /// Fetches `/app/config` and evaluates it against the installed version.
    /// Fails open: any network/decode error (or timeout) resolves to `.upToDate`
    /// so a config outage never bricks the app.
    func fetchUpdateOutcome() async -> AppUpdateOutcome
}

// MARK: - Service

final class AppConfigService: AppConfigServiceProtocol {
    
    private let network: NetworkServiceProtocol
    private let currentVersion: String
    private let timeout: TimeInterval
    private static let maintenanceMessage =
    "MovoCash is temporarily unavailable for scheduled maintenance. Please try again shortly."
    
    init(
        network: NetworkServiceProtocol,
        currentVersion: String = AppInfo.version,
        timeout: TimeInterval = 5
    ) {
        self.network = network
        self.currentVersion = currentVersion
        self.timeout = timeout
    }
    
    func fetchUpdateOutcome() async -> AppUpdateOutcome {
        do {
            let response: AppCheckResponse = try await withTimeout(timeout) { [network] in
                let result: AppCheckResponse = try await network.request(AuthAPI.appCheck)
                return result
            }
            let outcome = Self.evaluate(config: response.data, currentVersion: currentVersion)
            SecureLogger.info(
                "App config: installed=\(currentVersion) min=\(response.data.minimumSupportedVersion) latest=\(response.data.latestVersion) → \(outcome)",
                category: .network
            )
            await trackDecision(outcome, data: response.data)
            return outcome
        } catch {
            SecureLogger.error(
                "App config fetch failed — proceeding without update gate: \(error.localizedDescription)",
                category: .network
            )
            await track(AnalyticsEvent.appUpdateCheckFailed, errorMessage: error.localizedDescription)
            return .upToDate
        }
    }

    // MARK: - Analytics

    private func trackDecision(_ outcome: AppUpdateOutcome, data: AppCheckData) async {
        switch outcome {
        case .forceUpdate:
            await track(AnalyticsEvent.appUpdateForced, updateType: data.updateType, latestVersion: data.latestVersion)
        case .optionalUpdate:
            await track(AnalyticsEvent.appUpdateOptional, updateType: data.updateType, latestVersion: data.latestVersion)
        case .maintenance:
            await track(AnalyticsEvent.appMaintenance, updateType: data.updateType, latestVersion: data.latestVersion)
        case .upToDate:
            break
        }
    }

    private func track(
        _ event: String,
        updateType: String? = nil,
        latestVersion: String? = nil,
        errorMessage: String? = nil
    ) async {
        await MainActor.run {
            var params: [String: Any] = [:]
            if let updateType, !updateType.isEmpty { params[AnalyticsParam.updateType] = updateType }
            if let latestVersion, !latestVersion.isEmpty { params[AnalyticsParam.latestVersion] = latestVersion }
            if let errorMessage, !errorMessage.isEmpty { params[AnalyticsParam.errorMessage] = errorMessage }
            AnalyticsManager.shared.log(event, params: params.isEmpty ? nil : params)
        }
    }
    
    // MARK: - Evaluation
    
    static func evaluate(config: AppCheckData, currentVersion: String) -> AppUpdateOutcome {
        // Maintenance is signalled through the update type.
        if config.type == .maintenance {
            let message = config.updateMessage.isEmpty ? maintenanceMessage : config.updateMessage
            return .maintenance(title: config.updateTitle ?? "", message: message)
        }
        
        // Compare the installed version (AppInfo.version) against the response.
        let hasLatest    = !config.latestVersion.isEmpty
        let belowMinimum = isVersion(currentVersion, olderThan: config.minimumSupportedVersion)
        let belowLatest  = isVersion(currentVersion, olderThan: config.latestVersion)
        let serverForces = config.forceUpdate || config.type == .mandatory
        
        // Hard block when the install is below the minimum supported version, OR
        if belowMinimum || (serverForces && (belowLatest || !hasLatest)) {
            return .forceUpdate(
                type: config.type,
                title: config.updateTitle ?? "",
                message: config.updateMessage,
                storeURL: config.appStoreURL
            )
        }

        // Soft prompt: a newer, non-mandatory version is available.
        if belowLatest {
            return .optionalUpdate(
                type: config.type,
                title: config.updateTitle ?? "",
                message: config.updateMessage,
                storeURL: config.appStoreURL
            )
        }
        
        return .upToDate
    }
    
    /// Semantic-version comparison using numeric ordering so component values
    static func isVersion(_ lhs: String, olderThan rhs: String) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }
        return lhs.compare(rhs, options: .numeric) == .orderedAscending
    }
    
    // MARK: - Timeout
    
    /// Races `operation` against a timeout. Throws `AppConfigError.timedOut` if the
    /// timeout wins so the caller's fail-open catch resolves to `.upToDate`.
    private func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AppConfigError.timedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw AppConfigError.timedOut
            }
            return result
        }
    }
}

// MARK: - Error

enum AppConfigError: Error {
    case timedOut
}




//// 1️⃣ FORCE UPDATE (blocking — "Update Now" only)
//return AppCheckResponse(success: true, data: AppCheckData(
//    latestVersion: "99.0.0",
//    minimumSupportedVersion: "99.0.0",   // installed is below min → hard block
//    forceUpdate: true,
//    updateType: "mandatory",
//    updateMessage: "A new version is available. Please update to continue.",
//    appStoreUrl: "https://apps.apple.com/app/id1538828856"
//))
//
// 2️⃣ SOFT / OPTIONAL UPDATE (dismissible prompt — Update / Cancel)
//return AppCheckResponse(success: true, data: AppCheckData(
//    latestVersion: "99.0.0",             // above installed → below latest
//    minimumSupportedVersion: "0.0.0",    // installed NOT below min
//    forceUpdate: false,
//    updateType: "feature",
//    updateMessage: "Version 99.0.0 is now available with new features.",
//    appStoreUrl: "https://apps.apple.com/app/id1538828856"
//))
// 3️⃣ MAINTENANCE (blocking — "Try Again")
//return AppCheckResponse(success: true, data: AppCheckData(
//    latestVersion: "",
//    minimumSupportedVersion: "",
//    forceUpdate: false,
//    updateType: "maintenance",           // type drives maintenance
//    updateMessage: "MovoCash is temporarily unavailable for scheduled maintenance. Please try again shortly.",
//    appStoreUrl: ""
//))
//
// 4️⃣ UP TO DATE (no gate — app proceeds)
//return AppCheckResponse(success: true, data: AppCheckData(
//    latestVersion: "0.0.1",              // below installed → not below latest
//    minimumSupportedVersion: "0.0.1",
//    forceUpdate: false,
//    updateType: "unknown",
//    updateMessage: "",
//    appStoreUrl: ""
//))
