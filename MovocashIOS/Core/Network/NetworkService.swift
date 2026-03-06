//
//  NetworkService.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

actor NetworkService: NetworkServiceProtocol {
    
    static let shared = NetworkService()
    
    private let builder: RequestBuilder
    
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
        self.builder = RequestBuilder()
    }
    
    // MARK: - Public Request
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        
        // Security check
        if await JailbreakDetector.shared.isJailbroken {
            throw NetworkError.securityViolation
        }
        
        // Build the request
        let request = try await builder.build(from: endpoint)
        
        guard let url = request.url else {
            throw NetworkError.invalidURL
        }
        
        SecureLogger.debug("API URL: \(url)", category: .network)
        
        do {
            return try await performRequest(request)
        } catch let error as NetworkError {
            let retry = retryTracker[url] ?? 0
            guard retry < maxRetry else { throw error }
            
            retryTracker[url] = retry + 1
            
            switch error {
            case .unauthorized:
                try await refreshToken()
            case .rateLimited, .serverError:
                try await Task.sleep(nanoseconds: 200_000_000)
            default:
                throw error
            }
            
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
        
        guard !refreshToken.isEmpty else {
            throw NetworkError.unauthorized
        }
        
        let endpoint = AuthAPI.refreshToken(refreshToken: refreshToken)
        // Build the request
        let request = try await builder.build(from: endpoint)
        
        let response: RefreshTokenResponse = try await performRequest(request)
        
        try await AppContainer.shared.sessionManager.storeTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
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
            SecureLogger.error("Network error: \(error.localizedDescription)", category: .network)
            throw NetworkError.noInternet
        }
        
        // Validate HTTP response
        guard let http = response as? HTTPURLResponse else {
            SecureLogger.error("Invalid response for URL: \(request.url?.absoluteString ?? "Unknown")", category: .network)
            throw NetworkError.invalidResponse
        }
        
        SecureLogger.info("API Status Code: \(http.statusCode)", category: .network)
        
        if http.statusCode == 401 {
            throw NetworkError.unauthorized
        }
        
        if http.statusCode == 429 {
            throw NetworkError.rateLimited
        }
        
        if (500...599).contains(http.statusCode) {
            throw NetworkError.serverError
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                SecureLogger.error("API Error: \(apiError.message)", category: .network)
                throw NetworkError.serverMessage(apiError.message)
            }
            throw NetworkError.unknown
        }
        
        SecureLogger.debug("Response :\(String(data: data, encoding: .utf8) ?? "")", category: .network)
        // Decode successful response
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            SecureLogger.error("Decoding error for URL: \(request.url?.absoluteString ?? "Unknown") - \(error.localizedDescription)", category: .network)
            throw NetworkError.decodingError
        }
    }
}
