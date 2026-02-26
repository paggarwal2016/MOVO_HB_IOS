//
//  NetworkClient.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

actor NetworkClient: NetworkService {

    private let session: URLSession
    private var refreshTask: Task<Void, Error>?
    private var retryCounts: [URL: Int] = [:]
    private let maxRetryCount = 1

    init() {
        let delegate = SecureSessionDelegate(enabled: false) // TODO: AI info - MITM attack risk
        self.session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }

    // MARK: - Public Request

    func request<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T {

        if JailbreakDetector.shared.isJailBroken {
            // TODO: - Force logout & block API Block network request safely
            throw NetworkError.serverMessage("Device security compromised")
        }

        guard let urlRequest = endpoint.urlRequest,
              let url = urlRequest.url else {
            throw NetworkError.invalidResponse
        }

        var request = urlRequest

        if endpoint.requiresAuth,
           let token = AuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            return try await performRequest(request)
        } catch let error as NetworkError where error == .unauthorized {

            let currentRetry = retryCounts[url] ?? 0
            guard currentRetry < maxRetryCount else {
                retryCounts[url] = nil
                throw NetworkError.unauthorized
            }

            retryCounts[url] = currentRetry + 1

            try await refreshToken()

            // Re-attach the fresh token
            if let token = AuthManager.shared.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let result: T = try await performRequest(request)
            retryCounts[url] = nil
            return result

        } catch {
            retryCounts.removeAll()
            throw error
        }
    }
}


// MARK: - Perform Request

private extension NetworkClient {

    func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {

        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                throw NetworkError.noInternet
            case .timedOut:
                throw NetworkError.serverMessage("Request timed out")
            default:
                throw NetworkError.serverMessage(urlError.localizedDescription)
            }
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if http.statusCode == 401 {
            throw NetworkError.unauthorized
        }

        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw NetworkError.serverMessage(apiError.message)
            }
            throw NetworkError.unknown
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
}


// MARK: - Token Refresh (Coalescing)

private extension NetworkClient {

    func refreshToken() async throws {

        // If a refresh is already in flight, coalesce by awaiting the same task
        if let existing = refreshTask {
            try await existing.value
            return
        }

        let refreshTokenString: String
        do {
            refreshTokenString = try KeychainManager.shared.get("refresh_token")
        } catch {
            // TODO: No refresh token, call force logout()
            throw NetworkError.unauthorized
        }

        guard let request = AuthAPI.refreshToken(refreshToken: refreshTokenString).urlRequest else {
            throw NetworkError.invalidResponse
        }

        let task = Task<Void, Error> {
            let response: RefreshTokenResponse = try await performRequest(request)
            AuthManager.shared.updateAccessToken(response.accessToken)
            try? KeychainManager.shared.save(
                response.refreshToken,
                for: "refresh_token",
                biometricProtected: BiometricManager.isAvailable
            )
        }

        refreshTask = task

        do {
            try await task.value
            refreshTask = nil
        } catch {
            refreshTask = nil
            // TODO: failed call force logout()
            throw error
        }
    }
}
