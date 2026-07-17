//
//  NetworkServiceProtocol.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

protocol NetworkServiceProtocol: Sendable {
    func request<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T
    func requestData(_ endpoint: Endpoint) async throws -> Data
}
