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

    private let network: NetworkClient

    init(network: NetworkClient = .shared) {
        self.network = network
    }

    func sendOTP(phone: String, context: String) {
        guard state != .loading else { return }
        state = .loading

        Task { @MainActor in
            do {
                let _: SuccessResponse = try await network.request(
                    AuthAPI.messengerOTP(phoneNumber: phone, context: context)
                )
                self.state = .otpSent
                self.showOTP = true
            } catch {
                self.state = .idle
                AlertManager.shared.showError(error.localizedDescription)
            }
        }
    }

    func validateOTP(phone: String, code: String) {
        guard state != .loading else { return }
        state = .loading

        Task { @MainActor in
            do {
                let response: RefreshTokenResponse = try await network.request(
                    AuthAPI.tokenSMS(phoneNumber: phone, code: code)
                )
                // Update access token safely
                await AuthManager.shared.updateAccessToken(response.accessToken)
                
                // Save refresh token
                try KeychainManager.shared.save(
                    response.refreshToken,
                    for: "refresh_token",
                    protection: .backgroundSafe
                )
                
                self.state = .verified
            } catch {
                self.state = .idle
                AlertManager.shared.showError(error.localizedDescription)
            }
        }
    }
}

enum AuthState: Equatable {
    case idle
    case loading
    case otpSent
    case verified
    case error(String)
}
