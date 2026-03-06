//
//  AppContainer.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation

final class AppContainer {
    
    static let shared = AppContainer()
    
    let network: NetworkServiceProtocol
    let keychain: KeychainManagerProtocol
    let authManager: AuthManagerProtocol
    let sessionManager: SessionManager
    
    init() {
        network = NetworkService.shared
        keychain = KeychainManager.shared
        authManager = AuthManager.shared
        sessionManager = SessionManager(
            authManager: authManager,
            keychain: keychain
        )
    }
    
    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(network: network,
                      keychain: keychain,
                      authManager: authManager)
    }
}
