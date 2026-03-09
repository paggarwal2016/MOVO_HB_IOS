//
//  AuthViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var state: AuthState = .idle
    @Published var showOTP: Bool = false
    @Published var phoneNumber: String = ""
    @Published var context: String = ""
    
    private let network: NetworkServiceProtocol
    private let keychain: KeychainManagerProtocol
    private let authManager: AuthManagerProtocol
    private let sessionManager: SessionManager
    private let kycManager: KYCManagerProtocol
    private let alertManager: AlertManagerProtocol

    init(
        network: NetworkServiceProtocol,
        keychain: KeychainManagerProtocol,
        authManager: AuthManagerProtocol,
        sessionManager: SessionManager,
        kycManager: KYCManagerProtocol,
        alertManager: AlertManagerProtocol
    ) {
        self.network = network
        self.keychain = keychain
        self.authManager = authManager
        self.sessionManager = sessionManager
        self.kycManager = kycManager
        self.alertManager = alertManager
    }
    
    //MARK: - Send OTP
    
    func sendOTP() async throws {
        guard state != .loading else { return }
        state = .loading
        
        do {
            let _: SuccessResponse = try await network.request(
                AuthAPI.messengerOTP(phoneNumber: phoneNumber, context: context)
            )
            state = .otpSent
            showOTP = true
        } catch {
            state = .idle
            throw error
        }
    }
    
    //MARK: - Validate OTP

    func validateOTP(code: String) async throws -> RefreshTokenResponse  {
        guard state != .loading else { throw NSError(domain: "AlreadyLoading", code: 0) }
        state = .loading

        do {
            let response: RefreshTokenResponse = try await network.request(
                AuthAPI.tokenSMS(phoneNumber: phoneNumber, code: code)
            )
            self.state = .verified
            return response
        } catch {
            state = .idle
            throw error
        }
    }

    // MARK: - Complete OTP Verification Flow

    func completeOTPVerification(code: String, appState: AppState) async {
        do {
            let response = try await validateOTP(code: code)

            try await sessionManager.startSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                appState: appState
            )

            await kycManager.configureSDK(officeId: "1")

            appState.otpVerified = true
            phoneNumber = ""

            if appState.context == PhoneFlowType.login.rawValue {
                appState.flow = .home
            } else {
                appState.flow = .kyc
            }
        } catch {
            alertManager.showError(error.localizedDescription)
        }
    }

    // MARK: - Submit Phone Number

    func submitPhoneNumber(appState: AppState) async {
        let phone = PhoneNumberValidator.sanitize(phoneNumber)

        guard PhoneNumberValidator.isValidUSNumber(phone) else {
            alertManager.showError("Enter a valid phone number")
            return
        }

        phoneNumber = PhoneNumberValidator.normalize(phone)
        context = appState.context

        do {
            try await sendOTP()
            appState.flow = .otp
        } catch {
            alertManager.showError(error.localizedDescription)
        }
    }
}

//MARK: - AuthState

enum AuthState: Equatable {
    case idle
    case loading
    case otpSent
    case verified
    case error(String)
}
