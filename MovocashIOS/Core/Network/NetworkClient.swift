//
//  NetworkClient.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

actor NetworkClient {
    
    static let shared = NetworkClient()
    
    // Actor-protected state
    private var isRefreshing = false
    private var retryTracker: [URL: Int] = [:]
    private let maxRetry = 1
    
    // Custom session for security
    private let session: URLSession
    
    private init() {
        
        let config = URLSessionConfiguration.default

        // Fintech-safe timeout settings
        config.timeoutIntervalForRequest = 15        // Per request timeout
        config.timeoutIntervalForResource = 30       // Total resource timeout
        
        // Security best practices
        config.waitsForConnectivity = true           // Wait for network recovery
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        
        self.session = URLSession(
            configuration: config,
            delegate: SecureSessionDelegate(), // customizable
            delegateQueue: nil
        )
    }
    
    // MARK: - Public Request
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        
        // Security check
        if await JailbreakDetector.shared.isJailBroken {
            throw NetworkError.securityViolation
        }
        
        guard var request = await endpoint.urlRequest,
              let url = request.url else {
            throw NetworkError.invalidResponse
        }
        
        // Attach auth token if required
        if endpoint.requiresAuth,
           let token = await AuthManager.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            return try await performRequest(request)
        } catch NetworkError.unauthorized {
            // Retry logic for 401
            let retry = retryTracker[url] ?? 0
            guard retry < maxRetry else { throw NetworkError.unauthorized }
            
            retryTracker[url] = retry + 1
            try await refreshToken()
            retryTracker[url] = nil
            
            return try await performRequest(request)
        }
    }
    
    // MARK: - Refresh Token
    private func refreshToken() async throws {
        if isRefreshing {
            while isRefreshing {
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            return
        }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        let refreshToken = try await KeychainManager.shared.get("refresh_token")
        
        guard let request = await AuthAPI.refreshToken(refreshToken: refreshToken).urlRequest else {
            throw NetworkError.invalidResponse
        }
        
        // Decode off actor
        let response: RefreshTokenResponse = try await Task.detached {
            try await NetworkClient.shared.performRequest(request)
        }.value
        
        // Update actor-protected state safely
        await AuthManager.shared.updateAccessToken(response.accessToken)
        
        try await KeychainManager.shared.save(
            response.refreshToken,
            for: "refresh_token",
            protection: .backgroundSafe
        )
    }
    
    // MARK: - Perform Request (Nonisolated for Swift 6 concurrency)
    private nonisolated func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        
        // Use a separate URLSession
        let session = URLSession.shared
        
        // Network call
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            await SecureLogger.error("Network error: \(error.localizedDescription)", category: .network)
            throw NetworkError.noInternet
        }
        
        // Validate HTTP response
        guard let http = response as? HTTPURLResponse else {
            await SecureLogger.error("Invalid response for URL: \(request.url?.absoluteString ?? "Unknown")", category: .network)
            throw NetworkError.invalidResponse
        }
        
        await SecureLogger.info("API Status Code: \(http.statusCode)", category: .network)
        
        if http.statusCode == 401 {
            throw NetworkError.unauthorized
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                await SecureLogger.error("API Error: \(apiError.message)", category: .network)
                throw NetworkError.serverMessage(apiError.message)
            }
            throw NetworkError.unknown
        }
        
        await SecureLogger.debug("Response :\(String(data: data, encoding: .utf8) ?? "")", category: .network)
        // Decode successful response
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            await SecureLogger.error("Decoding error for URL: \(request.url?.absoluteString ?? "Unknown") - \(error.localizedDescription)", category: .network)
            throw NetworkError.decodingError
        }
    }
}
