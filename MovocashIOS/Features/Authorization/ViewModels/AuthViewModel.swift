//
//  AuthViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import SwiftUI
import Combine

final class AuthViewModel: ObservableObject {
    
    @Published var state: AuthState = .idle
    @Published var showOTP: Bool = false
    
    private let network: NetworkService
    private var cancellables = Set<AnyCancellable>()
        
    init(network: NetworkService) {
        self.network = network
    }
    
    func sendOTP(phone: String, context: String) {
        
        guard state != .loading else { return }
        state = .loading
        
        network.request(AuthAPI.messengerOTP(phoneNumber: phone, context: context))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                if case .failure(let error) = completion {
                    state = .idle
                    AlertManager.shared.showError(error.localizedDescription)
                }
            } receiveValue: { (response: SuccessResponse) in
                self.state = .otpSent
                self.showOTP = true  // <-- trigger navigation
            }
            .store(in: &cancellables)
    }
    
    
    func validateOTP(phone: String, code: String) {
        
        guard state != .loading else { return }
        state = .loading
        
        network.request(AuthAPI.tokenSMS(phoneNumber: phone, code: code))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                
                if case .failure(let error) = completion {
                    state = .idle
                    AlertManager.shared.showError(error.localizedDescription)
                }
                
            } receiveValue: { [weak self] (response: RefreshTokenResponse) in
                guard let self = self else { return }
                
                AuthManager.shared.updateAccessToken(response.accessToken)
                // Save refresh token safely
                do {
                    try KeychainManager.shared.save(
                        response.refreshToken,
                        for: "refresh_token",
                        biometricProtected: BiometricManager.isAvailable
                    )
                } catch {
                    AlertManager.shared.showError("Failed to save token: \(error.localizedDescription)")
                }
                self.state = .verified
            }
            .store(in: &cancellables)
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
