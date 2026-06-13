//
//  NetworkService.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

actor NetworkService: NetworkServiceProtocol {

    static let shared = NetworkService(
        keychain: KeychainManager.shared
    )

    private let builder: RequestBuilder
    private let keychain: KeychainManagerProtocol

    // Actor-protected state
    private var isRefreshing = false
    /// Callers that arrived while a refresh was already in-flight are parked here.
    /// When the refresh completes (or fails) every waiter is resumed exactly once.
    private var refreshWaiters: [CheckedContinuation<Void, Error>] = []
    private let maxAttempts = 3  // 1 initial attempt + 2 retries


    // Custom session for security
    private let session: URLSession

    init(
        keychain: KeychainManagerProtocol
    ) {
        self.keychain = keychain

        let config = URLSessionConfiguration.default

        // Fintech-safe timeout settings
        config.timeoutIntervalForRequest = 60        // Per request timeout
        config.timeoutIntervalForResource = 120       // Total resource timeout

        // Security best practices
        config.waitsForConnectivity = false          // Fail fast — noInternet error handled in URLError categorization
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.allowsCellularAccess = true
        config.networkServiceType = .responsiveData
        config.httpMaximumConnectionsPerHost = 5
        config.multipathServiceType = .handover

        self.session = URLSession(
            configuration: config,
            delegate: SecureSessionDelegate(enabled: false), // TODO: - configure the cert and set true
            delegateQueue: nil
        )
        self.builder = RequestBuilder()
    }
    
    // MARK: - Public Request
    func request<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T {

        // Session gate — block all outbound calls once the session has expired,
        // except auth endpoints (OTP, token exchange) so re-login is always possible.
        if await SessionGate.shared.isExpired, await !endpoint.isAuth {
            if await SessionGate.shared.isLoggingOut {
                throw CancellationError()
            }
            throw NetworkError.unauthorized
        }

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

        // Whether this endpoint sends the X25519 secure movo-info header — gates
        // the reactive device-session re-config below.
        let usesDeviceSession = await endpoint.headerType.has(.secureDeviceInfo)

        // Attempt the initial request, then retry up to maxAttempts - 1 times.
        var lastError: NetworkError = .unknown

        for attempt in 0..<maxAttempts {
            do {
                if attempt == 0 {
                    return try await performRequest(request, usesDeviceSession: usesDeviceSession)
                } else {
                    let retryRequest = try await builder.build(from: endpoint)
                    return try await performRequest(retryRequest, usesDeviceSession: usesDeviceSession)
                }
            } catch let error as NetworkError {
                lastError = error

                // Only retry on specific recoverable errors.
                // All other errors throw immediately — no retry.
                switch error {
                case .rateLimited, .serverError, .timeout, .noInternet:
                    // 429 / 5xx / timeout / no connectivity — retry with exponential backoff
                    guard attempt < maxAttempts - 1 else { throw error }
                    let backoff = UInt64(500_000_000) * UInt64(attempt + 1) // 500ms, 1000ms
                    let jitter  = UInt64.random(in: 0..<100_000_000)        // up to 100ms
                    try await Task.sleep(nanoseconds: backoff + jitter)

                default:
                    // 401, decode error, any other client error — throw immediately, no retry
                    throw error
                }
            }
        }

        throw lastError
    }

    // MARK: - Raw Data Request
    func requestData(_ endpoint: Endpoint) async throws -> Data {

        // Session gate — same guard as request()
        if await SessionGate.shared.isExpired, await !endpoint.isAuth {
            if await SessionGate.shared.isLoggingOut {
                throw CancellationError()
            }
            throw NetworkError.unauthorized
        }

        if await JailbreakDetector.shared.isJailbroken {
            throw NetworkError.securityViolation
        }

        let request = try await builder.build(from: endpoint)

        guard let url = request.url else {
            throw NetworkError.invalidURL
        }

        SecureLogger.debug("API URL: \(url)", category: .network)

        let usesDeviceSession = await endpoint.headerType.has(.secureDeviceInfo)

        var lastError: NetworkError = .unknown

        for attempt in 0..<maxAttempts {
            do {
                if attempt == 0 {
                    return try await performRawRequest(request, usesDeviceSession: usesDeviceSession)
                } else {
                    let retryRequest = try await builder.build(from: endpoint)
                    return try await performRawRequest(retryRequest, usesDeviceSession: usesDeviceSession)
                }
            } catch let error as NetworkError {
                lastError = error
                switch error {
                case .rateLimited, .serverError, .timeout, .noInternet:
                    guard attempt < maxAttempts - 1 else { throw error }
                    let backoff = UInt64(500_000_000) * UInt64(attempt + 1)
                    let jitter  = UInt64.random(in: 0..<100_000_000)
                    try await Task.sleep(nanoseconds: backoff + jitter)
                default:
                    throw error
                }
            }
        }

        throw lastError
    }

    // MARK: - Refresh Token
//    private func refreshToken() async throws { // TODO: Vinu
//        if isRefreshing {
//            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
//                refreshWaiters.append(continuation)
//            }
//            return
//        }
//
//        isRefreshing = true
//        defer { isRefreshing = false }
//
//        do {
//            let token = try await keychain.get("access_token", biometricPrompt: nil)
//
//            // Empty token throws and falls through to the single catch below,
//            // which is the only place resumeWaiters is called for error paths.
//            guard !token.isEmpty else { throw NetworkError.unauthorized }
//
//            let endpoint = AuthAPI.refreshToken(refreshToken: token)
//            let request = try await builder.build(from: endpoint)
//            let response: RefreshTokenResponse = try await performRequest(request)
//
//            // Store refreshed token — Keychain is the single source of truth
//            try await keychain.save(response.accessToken, for: "access_token", protection: .backgroundSafe)
//            await AnalyticsManager.shared.reapplyIdentity()
//
//            resumeWaiters(throwing: nil)       // success — single resume point
//        } catch {
//            resumeWaiters(throwing: error)     // all failures — single resume point
//            throw error
//        }
//    }

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
    private nonisolated func performRequest<T: Decodable>(_ request: URLRequest, usesDeviceSession: Bool = false) async throws -> T {
        
#if DEBUG
        debugPrintRequest(request)
#endif

        // Duration tracking — logs on all exit paths (success, network error, decode error)
        let start = Date()
        defer {
            let ms = Date().timeIntervalSince(start) * 1000
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd hh:mm:ss.SSS"
            let timestamp = formatter.string(from: start)
            SecureLogger.info(
                "[\(timestamp)] [\(request.httpMethod ?? "?")] \(request.url?.path ?? "unknown") — Duration: \(String(format: "%.0f", ms))ms",
                category: .network
            )
        }
        
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

        if SessionExpiryNotifier.shouldTerminateSession(statusCode: http.statusCode, data: data) {
            let message = SessionExpiryNotifier.displayMessage(statusCode: http.statusCode, data: data)
            Task { @MainActor in
                await SessionExpiryNotifier.postIfNeeded(message: message)
            }
            throw NetworkError.unauthorized
        }

        if http.statusCode == 429 {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw NetworkError.serverMessage(apiError.message)
            }
            throw NetworkError.rateLimited
        }

        if (500...599).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw NetworkError.serverMessage(apiError.message)
            }
            throw NetworkError.serverError
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                SecureLogger.error("API Error: \(apiError.message)", category: .network)
                throw NetworkError.serverMessage(apiError.message)
            }
            throw NetworkError.apiError(http.statusCode)
        }
        
        // 204 No Content — the resource genuinely does not exist yet.
        // Callers that expect an optional result catch NetworkError.noContent.
        if http.statusCode == 204 {
            throw NetworkError.noContent
        }

        // Decode successful response — treat empty body on other 2xx as `{}`
        let decodableData = data.isEmpty ? Data("{}".utf8) : data
        do {
            let decoded = try await JSONDecoder.fintechDecoder.decode(T.self, from: decodableData)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastActivityAt")
            return decoded
        } catch {
            SecureLogger.error("Decoding error for URL: \(request.url?.absoluteString ?? "Unknown") - \(error.localizedDescription)", category: .network)
            throw NetworkError.decodingError
        }
    }

    // MARK: - Perform Raw Request
    private nonisolated func performRawRequest(_ request: URLRequest, usesDeviceSession: Bool = false) async throws -> Data {

#if DEBUG
        debugPrintRequest(request)
#endif

        let start = Date()
        defer {
            let ms = Date().timeIntervalSince(start) * 1000
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd hh:mm:ss.SSS"
            let timestamp = formatter.string(from: start)
            SecureLogger.info(
                "[\(timestamp)] [\(request.httpMethod ?? "?")] \(request.url?.path ?? "unknown") — Duration: \(String(format: "%.0f", ms))ms",
                category: .network
            )
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .internationalRoamingOff, .callIsActive:
                throw NetworkError.noInternet
            case .timedOut:
                throw NetworkError.timeout
            case .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid, .serverCertificateHasBadDate,
                 .clientCertificateRejected, .clientCertificateRequired,
                 .secureConnectionFailed, .cannotLoadFromNetwork:
                throw NetworkError.securityViolation
            default:
                throw NetworkError.requestFailed(urlError.localizedDescription)
            }
        } catch {
            throw NetworkError.requestFailed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if SessionExpiryNotifier.shouldTerminateSession(statusCode: http.statusCode, data: data) {
            let message = SessionExpiryNotifier.displayMessage(statusCode: http.statusCode, data: data)
            Task { @MainActor in
                await SessionExpiryNotifier.postIfNeeded(message: message)
            }
            throw NetworkError.unauthorized
        }

        if http.statusCode == 429 {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw NetworkError.serverMessage(apiError.message)
            }
            throw NetworkError.rateLimited
        }
        if (500...599).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw NetworkError.serverMessage(apiError.message)
            }
            throw NetworkError.serverError
        }
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw NetworkError.serverMessage(apiError.message)
            }
            throw NetworkError.apiError(http.statusCode)
        }

        SecureLogger.info("API Success.", category: .network)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastActivityAt")
        return data
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








extension JSONDecoder {
    static var fintechDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            if let date = isoFormatter.date(from: dateStr) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(dateStr)"
            )
        }
        
        return decoder
    }
}
