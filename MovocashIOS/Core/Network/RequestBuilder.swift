//
//  RequestBuilder.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation

final class RequestBuilder: Sendable {
    
    func build(from endpoint: Endpoint) async throws -> URLRequest {
        
        // 1. Build URL
        guard var components = URLComponents(
            url: endpoint.environment.baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidURL
        }
        
        components.path += endpoint.path
        components.queryItems = endpoint.queryItems
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        // 2. Create Request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 15
        request.httpBody = endpoint.body
        
        // 3. Attach Headers
        let headers = await HeaderProvider.headers(for: endpoint.headerType)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        return request
    }
}
