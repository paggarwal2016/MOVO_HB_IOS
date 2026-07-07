//
//  RequestBuilder.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation

final class RequestBuilder: Sendable {

    init() {}

    func build(from endpoint: Endpoint, idempotencyKey: String? = nil, extraHeaders: [String: String] = [:]) async throws -> URLRequest {

        // 1. Build URL
        guard var components = URLComponents(
            url: AppConfig.baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidURL
        }

        components.path = "/\(endpoint.version.rawValue)" + endpoint.path
        components.queryItems = endpoint.queryItems

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        // 2. Create Request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 15
        request.httpBody = try endpoint.body

        // 3. Attach Headers — token read from Keychain inside HeaderProvider
        let headers = await HeaderProvider.headers(for: endpoint.headerType, idempotencyKey: idempotencyKey)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // 4. App Attest assertion headers, if any (computed by NetworkService — the
        //    assertion binds to this request's body, so it can't be built here).
        extraHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        return request
    }
}
