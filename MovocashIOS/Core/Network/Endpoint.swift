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
    var headerType: HeaderType { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
}
