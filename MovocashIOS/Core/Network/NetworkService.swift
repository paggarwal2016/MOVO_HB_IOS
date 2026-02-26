//
//  NetworkService.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

nonisolated protocol NetworkService: Sendable {
    func request<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T
}
