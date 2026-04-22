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
    case apiError(Int)
    case rateLimited
    case serverError
    case noInternet
    case timeout
    case requestFailed(String)
    case securityViolation
    case invalidURL
    case encodingError
    case noContent
    case unknown

    var errorDescription: String? {
        switch self {

        case .invalidResponse:
            return "Invalid server response"

        case .unauthorized:
            return "Session expired. Please login again."

        case .decodingError:
            return "Unable to process server data"

        case .serverMessage(let msg):
            return msg

        case .apiError(let code):
            return "Request failed with status code \(code)"

        case .rateLimited:
            return "Too many requests. Please try again later."

        case .serverError:
            return "Server is currently unavailable. Please try again."

        case .noInternet:
            return "No internet connection"

        case .timeout:
            return "The request timed out. Please try again."

        case .requestFailed(let reason):
            return "Request failed: \(reason)"

        case .securityViolation:
            return "Secure connection failed. Please check your network."

        case .invalidURL:
            return "Invalid URL"

        case .encodingError:
            return "Failed to encode request data"

        case .noContent:
            return nil

        case .unknown:
            return "Something went wrong"
        }
    }
}
