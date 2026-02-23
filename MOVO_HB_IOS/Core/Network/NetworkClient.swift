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
    
    init() {
        let delegate = SecureSessionDelegate(enabled: false)
        self.session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }
    
    func request<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, Error> {
      
        // TODO: - Enable future
//        if JailbreakDetector.shared.isJailBroken {
//            fatalError("Jailbroken device detected.")
//        }
        
        guard let urlRequest = endpoint.urlRequest else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = urlRequest
        
        if endpoint.requiresAuth,
           let token = KeychainManager.shared.get("accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return performRequest(request)
            .catch { [weak self] error -> AnyPublisher<T, Error> in
                
                guard let self = self else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                
                if case NetworkError.unauthorized = error {
                    return self.refreshTokenPublisher()
                        .flatMap { _ in
                            self.performRequest(request)
                        }
                        .eraseToAnyPublisher()
                }
                
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}


private extension NetworkClient {
    
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
            return refreshPublisher ?? Fail(error: URLError(.cannotLoadFromNetwork))
                .eraseToAnyPublisher()
        }
        
        guard let refreshToken = KeychainManager.shared.get("refreshToken") else {
            return Fail(error: URLError(.userAuthenticationRequired))
                .eraseToAnyPublisher()
        }
        
        isRefreshing = true
        
        let endpoint = AuthAPI.refreshToken(refreshToken: refreshToken)
        
        guard let request = endpoint.urlRequest else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        refreshPublisher = performRequest(request)
            .handleEvents(receiveOutput: { (response: RefreshTokenResponse) in
                
                KeychainManager.shared.save(response.accessToken, for: "accessToken")
                KeychainManager.shared.save(response.refreshToken, for: "refreshToken")
            })
            .map { _ in () }
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.isRefreshing = false
            })
            .share()
            .eraseToAnyPublisher()
        
        return refreshPublisher!
    }
}








enum NetworkError: Error {
    case unauthorized
    case invalidResponse
}
