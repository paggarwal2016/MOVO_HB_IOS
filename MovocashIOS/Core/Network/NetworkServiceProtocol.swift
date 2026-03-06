//
//  NetworkServiceProtocol.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

protocol NetworkServiceProtocol {
    func request<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T
}
