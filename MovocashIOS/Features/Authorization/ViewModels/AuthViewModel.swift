//
//  AuthViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var state: AuthState = .idle
    @Published var showOTP: Bool = false

    private let network: NetworkService
    private var currentTask: Task<Void, Never>?

    init(network: NetworkService) {
        self.network = network
    }

    deinit {
        currentTask?.cancel()
    }

    func sendOTP(phone: String, context: String) {

        guard state != .loading else { return }
        state = .loading

        currentTask?.cancel()
        currentTask = Task {
            do {
                let _: SuccessResponse = try await network.request(
                    AuthAPI.messengerOTP(phoneNumber: phone, context: context)
                )
                state = .otpSent
                showOTP = true
            } catch is CancellationError {
                // Task was cancelled — no UI update needed
            } catch {
                state = .idle
                AlertManager.shared.showError(error.localizedDescription)
            }
        }
    }

    func validateOTP(phone: String, code: String) {

        guard state != .loading else { return }
        state = .loading

        currentTask?.cancel()
        currentTask = Task {
            do {
                let response: RefreshTokenResponse = try await network.request(
                    AuthAPI.tokenSMS(phoneNumber: phone, code: code)
                )

                AuthManager.shared.updateAccessToken(response.accessToken)

                do {
                    try KeychainManager.shared.save(
                        response.refreshToken,
                        for: "refresh_token",
                        biometricProtected: BiometricManager.isAvailable
                    )
                } catch {
                    AlertManager.shared.showError("Failed to save token: \(error.localizedDescription)")
                }

                state = .verified
            } catch is CancellationError {
                // Task was cancelled — no UI update needed
            } catch {
                state = .idle
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

extension AuthViewModel {
    var otpNavigationBinding: Binding<Bool> {
        Binding(
            get: {
                switch self.state {
                case .otpSent, .loading, .verified:
                    return true
                default:
                    return false
                }
            },
            set: { _ in }
        )
    }
}

extension AuthState {
    var isOTPSent: Bool {
        if case .otpSent = self { return true }
        return false
    }
}
