//
//  NetworkService.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

actor NetworkService: NetworkServiceProtocol {

    static let shared = NetworkService(
        keychain: KeychainManager.shared,
        authManager: AuthManager.shared
    )

    private let builder: RequestBuilder
    private let keychain: KeychainManagerProtocol
    private let authManager: AuthManagerProtocol

    // Actor-protected state
    private var isRefreshing = false
    /// Callers that arrived while a refresh was already in-flight are parked here.
    /// When the refresh completes (or fails) every waiter is resumed exactly once.
    private var refreshWaiters: [CheckedContinuation<Void, Error>] = []
    private var retryTracker: [URL: Int] = [:]
    private let maxRetry = 1

    // Custom session for security
    private let session: URLSession

    init(
        keychain: KeychainManagerProtocol,
        authManager: AuthManagerProtocol
    ) {
        self.keychain = keychain
        self.authManager = authManager

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
        self.builder = RequestBuilder(authManager: authManager)
    }
    
    // MARK: - Public Request
    func request<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T {
        
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
            let retryRequest = try await builder.build(from: endpoint)
            return try await performRequest(retryRequest)
        }
    }
    
    // MARK: - Refresh Token
    private func refreshToken() async throws {
        if isRefreshing {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                refreshWaiters.append(continuation)
            }
            return
        }

        isRefreshing = true

        do {
            let token = try await keychain.get("refresh_token", biometricPrompt: nil)

            guard !token.isEmpty else {
                isRefreshing = false
                resumeWaiters(throwing: NetworkError.unauthorized)
                throw NetworkError.unauthorized
            }

            let endpoint = AuthAPI.refreshToken(refreshToken: token)
            let request = try await builder.build(from: endpoint)
            let response: RefreshTokenResponse = try await performRequest(request)

            // Store refreshed tokens directly
            try await keychain.save(response.accessToken, for: "access_token", protection: .backgroundSafe)
            try await keychain.save(response.refreshToken, for: "refresh_token", protection: .backgroundSafe)
            await authManager.updateAccessToken(response.accessToken)

            isRefreshing = false
            resumeWaiters(throwing: nil)
        } catch {
            isRefreshing = false
            resumeWaiters(throwing: error)
            throw error
        }
    }

    private func resumeWaiters(throwing error: Error?) {
        let waiters = refreshWaiters
        refreshWaiters = []
        for waiter in waiters {
            if let error {
                waiter.resume(throwing: error)
            } else {
                waiter.resume()
            }
        }
    }
    
    // MARK: - Perform Request (Nonisolated for Swift 6 concurrency)
    private nonisolated func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        
#if DEBUG
        debugPrintRequest(request)
#endif

        // Network call
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .internationalRoamingOff, .callIsActive:
                SecureLogger.warning("No internet: \(urlError.code.rawValue)", category: .network)
                throw NetworkError.noInternet

            case .timedOut:
                SecureLogger.warning("Request timed out", category: .network)
                throw NetworkError.timeout

            case .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid, .serverCertificateHasBadDate,
                 .clientCertificateRejected, .clientCertificateRequired,
                 .secureConnectionFailed, .cannotLoadFromNetwork:
                SecureLogger.error("SSL/TLS failure (code \(urlError.code.rawValue)) — possible MITM", category: .network)
                throw NetworkError.securityViolation

            default:
                SecureLogger.error("URLError \(urlError.code.rawValue): \(urlError.localizedDescription)", category: .network)
                throw NetworkError.requestFailed(urlError.localizedDescription)
            }
        } catch {
            SecureLogger.error("Unexpected network error: \(error.localizedDescription)", category: .network)
            throw NetworkError.requestFailed(error.localizedDescription)
        }
        
        // Validate HTTP response
        guard let http = response as? HTTPURLResponse else {
            SecureLogger.error("Invalid response for URL: \(request.url?.absoluteString ?? "Unknown")", category: .network)
            throw NetworkError.invalidResponse
        }
        
#if DEBUG
        debugPrintResponse(data: data, response: response)
#endif
                
        SecureLogger.info("API Success.", category: .network)
        
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
        
        // Decode successful response — treat 204 / empty body as `{}`
        let decodableData = data.isEmpty ? Data("{}".utf8) : data
        do {
            return try JSONDecoder().decode(T.self, from: decodableData)
        } catch {
            SecureLogger.error("Decoding error for URL: \(request.url?.absoluteString ?? "Unknown") - \(error.localizedDescription)", category: .network)
            throw NetworkError.decodingError
        }
    }
}












// MARK: - Debug request and response - Future need remove
// TODO: -


extension NetworkService {
    
    nonisolated private func debugPrintRequest(_ request: URLRequest) {
        
        print("\n🚀 ===== REQUEST =====")
        
        if let method = request.httpMethod {
            print("Method: \(method)")
        }
        
        if let url = request.url {
            print("URL: \(url.absoluteString)")
        }
        
        if let headers = request.allHTTPHeaderFields {
            print("Headers: \(headers)")
        }
        
        if let body = request.httpBody,
           let json = try? JSONSerialization.jsonObject(with: body),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            
            print("Body:\n\(prettyString)")
            
        } else if let body = request.httpBody,
                  let bodyString = String(data: body, encoding: .utf8) {
            
            print("Body:\n\(bodyString)")
        }
        
        print("======================\n")
    }
    
    nonisolated private func debugPrintResponse(data: Data, response: URLResponse) {
        
        print("\n✅ ===== RESPONSE =====")
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Status Code: \(httpResponse.statusCode)")
            print("URL: \(httpResponse.url?.absoluteString ?? "")")
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            
            print("Response Body:\n\(prettyString)")
            
        } else if let responseString = String(data: data, encoding: .utf8) {
            
            print("Response Body:\n\(responseString)")
        }
        
        print("=======================\n")
    }
}
