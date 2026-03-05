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
    
    func sendOTP(phone: String, context: String) async throws {
        guard state != .loading else { return }
        state = .loading
        
        do {
            let _: SuccessResponse = try await network.request(
                AuthAPI.messengerOTP(phoneNumber: phone, context: context)
            )
            state = .otpSent
            showOTP = true
        } catch {
            state = .idle
            throw error
        }
    }
    
    
    func validateOTP(phone: String, code: String) async throws {
        guard state != .loading else { return }
        state = .loading
        
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
            
            // Configure SDK
            await KYCManager.shared.configureSDK(officeId: "1")
            
        } catch {
            state = .idle
            throw error
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
