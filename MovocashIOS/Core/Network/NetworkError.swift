//
//  NetworkError.swift
//  MovocashIOS
//
//  Created by Movo Developer on 26/02/26.
//

import Foundation

enum NetworkError: LocalizedError, Sendable {
    case invalidResponse
    case unauthorized
    case decodingError
    case serverMessage(String)
    case noInternet
    case securityViolation
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .unauthorized: return "Session expired. Please login again."
        case .decodingError: return "Unable to process server data"
        case .serverMessage(let msg): return msg
        case .noInternet: return "No internet connection"
        case .securityViolation: return "Secure connection failed"
        case .unknown: return "Something went wrong"
        }
    }
}
