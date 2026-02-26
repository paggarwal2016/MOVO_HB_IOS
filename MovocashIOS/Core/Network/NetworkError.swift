//
//  NetworkError.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

enum NetworkError: LocalizedError, Equatable {
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
