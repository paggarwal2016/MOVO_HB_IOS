//
//  AuthManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 24/02/26.
//
import Foundation

//MARK: - AuthManager

actor AuthManager: AuthManagerProtocol {

    static let shared = AuthManager()
    private init() {}

    private var accessToken: String?

    // READ
    func getAccessToken() async -> String? {
        accessToken
    }

    // WRITE
    func updateAccessToken(_ token: String) async {
        accessToken = token
    }

    func clearSession() async {
        accessToken = nil
    }
}


// MARK: - AuthManagerProtocol

protocol AuthManagerProtocol {
    func updateAccessToken(_ token: String) async
    func getAccessToken() async -> String?
    func clearSession() async
}
