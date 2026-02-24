//
//  NetworkClient.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation
import Combine

final class NetworkClient: NetworkService {
    
    private let session: URLSession
    private var isRefreshing = false
    private var refreshPublisher: AnyPublisher<Void, Error>?
    // Track retry attempts internally by request URL
    private var retryCounts: [URL: Int] = [:]
    private let maxRetryCount = 1
    
    init() {
        let delegate = SecureSessionDelegate(enabled: false) // TODO: AI info - MITM attack risk
        self.session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }
    
    func request<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, Error> {
        
        if JailbreakDetector.shared.isJailBroken {
            // TODO: - Force logout & block API Block network request safely
            return Fail(error: URLError(.userAuthenticationRequired))
                .eraseToAnyPublisher()
        }
        
        guard let urlRequest = endpoint.urlRequest,
              let url = urlRequest.url else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = urlRequest
        
        if endpoint.requiresAuth,
           let token = AuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return performRequest(request)
            .catch { [weak self] error -> AnyPublisher<T, Error> in
                
                guard let self = self else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                
                if case NetworkError.unauthorized = error {
                    // Track retry attempts internally
                    let currentRetry = self.retryCounts[url] ?? 0
                    if currentRetry < self.maxRetryCount {
                        self.retryCounts[url] = currentRetry + 1
                        return self.refreshTokenPublisher()
                            .flatMap { _ in
                                self.performRequest(request)
                            }
                            .handleEvents(receiveCompletion: { _ in
                                self.retryCounts[url] = nil // Reset retry after attempt
                            })
                            .eraseToAnyPublisher()
                    } else {
                        // TODO: - Exceeded retry limit, force logout
                    }
                }
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func performRequest<T: Decodable>(_ request: URLRequest) -> AnyPublisher<T, Error> {
        
        session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let http = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                // PRINT Status Code
                print("Api Status Code:", http.statusCode)
                
                if http.statusCode == 401 {
                    throw NetworkError.unauthorized
                }
                
                if !(200...299).contains(http.statusCode) {
                    throw URLError(.badServerResponse)
                }
                // PRINT RAW JSON
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON Response:", jsonString)
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}


private extension NetworkClient {
    
    func refreshTokenPublisher() -> AnyPublisher<Void, Error> {
        
        if isRefreshing {
            if let existingPublisher = refreshPublisher {
                return existingPublisher
            } else {
                return Fail(error: URLError(.cannotLoadFromNetwork))
                    .eraseToAnyPublisher()
            }
        }
        
        let refreshToken: String
        do {
            refreshToken = try KeychainManager.shared.get("refresh_token")
        } catch {
            // TODO: No refresh token, call force logout()
            return Fail(error: URLError(.userAuthenticationRequired))
                .eraseToAnyPublisher()
        }
        
        isRefreshing = true
        
        let endpoint = AuthAPI.refreshToken(refreshToken: refreshToken)
        
        guard let request = endpoint.urlRequest else {
            isRefreshing = false
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        // Create the refresh publisher
        let publisher: AnyPublisher<Void, Error> = performRequest(request)
            .handleEvents(receiveOutput: { (response: RefreshTokenResponse) in
                AuthManager.shared.updateAccessToken(response.accessToken)
                
                do {
                    try KeychainManager.shared.save(
                        response.refreshToken,
                        for: "refresh_token",
                        biometricProtected: BiometricManager.isAvailable
                    )
                } catch {
                    print("Failed to save token: \(error.localizedDescription)")
                }
            })
            .map { _ in () }
            .handleEvents(receiveCompletion: { [weak self] completion in
                self?.isRefreshing = false
                self?.refreshPublisher = nil
                if case .failure(_) = completion {
                    // TODO: failed call force logout()
                }
            })
            .share()
            .eraseToAnyPublisher()
        
        refreshPublisher = publisher
        return publisher
    }
}



enum NetworkError: Error {
    case unauthorized
    case invalidResponse
}
