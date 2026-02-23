//
//  APIEndpoint.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//
import Foundation

protocol Endpoint {
    var environment: Environment { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var header: [String: String]? { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
    var requiresAuth: Bool { get }
}


extension Endpoint {
    
    var urlRequest: URLRequest? {
        
        guard var components = URLComponents(string: environment.baseURL.absoluteString) else {
            return nil
        }
        components.path += path
        components.queryItems = queryItems
        guard let url = components.url else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        header?.forEach {
            request.setValue($1, forHTTPHeaderField: $0)
        }
        return request
    }
}
