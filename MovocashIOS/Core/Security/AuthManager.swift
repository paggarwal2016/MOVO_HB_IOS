//
//  AuthManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 24/02/26.
//
import Foundation

actor AuthManager {

    static let shared = AuthManager()
    private init() {}

    private var accessToken: String?

    // READ
    func getAccessToken() -> String? {
        accessToken
    }

    // WRITE
    func updateAccessToken(_ token: String) {
        accessToken = token
    }

    func clearSession() {
        accessToken = nil
    }
}
