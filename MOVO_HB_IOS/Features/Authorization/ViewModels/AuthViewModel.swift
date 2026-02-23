//
//  AuthViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import SwiftUI
import Combine

final class AuthViewModel: ObservableObject {
    
    private let network: NetworkService
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var isLoading = false
    @Published var otpSent = false
    @Published var kycProcess = false
    
    @Published var errorMessage: String?
    
    init(network: NetworkService = NetworkClient()) {
        self.network = network
    }
    
    func sendOTP(phone: String, context: String) {
        
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        network.request(AuthAPI.messengerOTP(phoneNumber: phone, context: context))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
                
            } receiveValue: { (response: SussessResponse) in
                self.otpSent = true
                print("OTP Success:", response)
            }
            .store(in: &cancellables)
    }
    
    
    func validateOTP(phone: String, code: String) {
        
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        network.request(AuthAPI.tokenSMS(phoneNumber: phone, code: code))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
                
            } receiveValue: { (response: RefreshTokenResponse) in
                KeychainManager.shared.save(response.accessToken, for: "accessToken")
                KeychainManager.shared.save(response.refreshToken, for: "refreshToken")
                self.kycProcess = true
            }
            .store(in: &cancellables)
    }
}
