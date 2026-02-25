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
    private var refreshPublisher: AnyPublisher<Void, NetworkError>?
    private var retryCounts: [URL: Int] = [:]
    private let maxRetryCount = 1
    
    init() {
        let delegate = SecureSessionDelegate(enabled: false)// TODO: AI info - MITM attack risk
        self.session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }
    
    // MARK: - PUBLIC REQUEST
    func request<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, NetworkError> {
        
        if JailbreakDetector.shared.isJailBroken {
            // TODO: - Force logout & block API Block network request safely
            return Fail(error: .serverMessage("Device security compromised"))
                .eraseToAnyPublisher()
        }
        
        guard let urlRequest = endpoint.urlRequest,
              let url = urlRequest.url else {
            return Fail(error: .invalidResponse)
                .eraseToAnyPublisher()
        }
        
        var request = urlRequest
        
        if endpoint.requiresAuth,
           let token = AuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return performRequest(request)
            .catch { [weak self] error -> AnyPublisher<T, NetworkError> in
                guard let self else { return Fail(error: error).eraseToAnyPublisher() }
                
                // TOKEN REFRESH FLOW
                if case .unauthorized = error {
                    
                    let currentRetry = self.retryCounts[url] ?? 0
                    guard currentRetry < self.maxRetryCount else {
                        return Fail(error: .unauthorized).eraseToAnyPublisher()
                    }
                    
                    self.retryCounts[url] = currentRetry + 1
                    
                    return self.refreshTokenPublisher()
                        .flatMap { self.performRequest(request) }
                        .handleEvents(receiveCompletion: { _ in
                            self.retryCounts[url] = nil
                        })
                        .eraseToAnyPublisher()
                } else {
                    // TODO: - Exceeded retry limit, force logout
                }
                
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}


extension NetworkClient {
    
    func performRequest<T: Decodable>(_ request: URLRequest) -> AnyPublisher<T, NetworkError> {
        
        session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                
                guard let http = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("Api Status Code:", http.statusCode)
                print("Raw JSON:", String(data: data, encoding: .utf8) ?? "")
                
                if http.statusCode == 401 {
                    throw NetworkError.unauthorized
                }
                
                if !(200...299).contains(http.statusCode) {
                    
                    if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        throw NetworkError.serverMessage(apiError.message)
                    }
                    
                    throw NetworkError.unknown
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { self.mapToNetworkError($0) }
            .eraseToAnyPublisher()
    }
    
    private func mapToNetworkError(_ error: Error) -> NetworkError {
        
        if let error = error as? NetworkError {
            return error
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet: return .noInternet
            case .timedOut: return .serverMessage("Request timed out")
            default: return .serverMessage(urlError.localizedDescription)
            }
        }
        
        if error is DecodingError {
            return .decodingError
        }
        
        return .unknown
    }
}


private extension NetworkClient {
    
    func refreshTokenPublisher() -> AnyPublisher<Void, NetworkError> {
        
        if isRefreshing {
            return refreshPublisher ?? Fail(error: .unknown).eraseToAnyPublisher()
        }
        
        let refreshToken: String
        do {
            refreshToken = try KeychainManager.shared.get("refresh_token")
        } catch {
            // TODO: No refresh token, call force logout()
            return Fail(error: .unauthorized).eraseToAnyPublisher()
        }
        
        isRefreshing = true
        
        guard let request = AuthAPI.refreshToken(refreshToken: refreshToken).urlRequest else {
            isRefreshing = false
            return Fail(error: .invalidResponse).eraseToAnyPublisher()
        }
        
        let publisher = performRequest(request)
            .handleEvents(receiveOutput: { (response: RefreshTokenResponse) in
                AuthManager.shared.updateAccessToken(response.accessToken)
                try? KeychainManager.shared.save(response.refreshToken, for: "refresh_token", biometricProtected: BiometricManager.isAvailable)
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


enum NetworkError: LocalizedError {
    case invalidResponse
    case unauthorized
    case decodingError
    case serverMessage(String)
    case noInternet
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Session expired. Please login again."
        case .decodingError:
            return "Unable to process server data"
        case .serverMessage(let message):
            return message
        case .noInternet:
            return "No internet connection"
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
