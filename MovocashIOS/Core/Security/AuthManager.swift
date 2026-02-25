//
//  AuthManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 24/02/26.
//
import Foundation

final class AuthManager {

    static let shared = AuthManager()
    private init() {}

    private let queue = DispatchQueue(label: "com.app.auth", attributes: .concurrent)
    private var _accessToken: String?

    var accessToken: String? { queue.sync { _accessToken } }

    func updateAccessToken(_ token: String) {
        queue.async(flags: .barrier) { self._accessToken = token }
    }

    func clearSession() {
        queue.async(flags: .barrier) { self._accessToken = nil }
    }
}
