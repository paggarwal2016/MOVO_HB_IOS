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
    case securityViolation
    case invalidURL
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
            
        case .securityViolation:
            return "Secure connection failed"
            
        case .invalidURL:
            return "Invalid URL"
            
        case .unknown:
            return "Something went wrong"
        }
    }
}
