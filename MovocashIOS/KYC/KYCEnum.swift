//
//  KYCEnum.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/03/26.
//

import Foundation
import MobileBankingSDK

// MARK: - KYC Result

enum KYCResult {
    case success(User)
    case failed(Error)
}

// MARK: - KYC Errors

enum KYCError: LocalizedError, Equatable {
    
    case notConfigured
    case noPresenter
    case cancelled
    case rejected
    case timeout
    case sdkError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Verification system not ready. Please try again."
        case .noPresenter:
            return "Unable to start verification."
        case .cancelled:
            return "Verification was cancelled."
        case .rejected:
            return "Verification was not approved."
        case .timeout:
            return "Verification timed out. Please try again."
        case .sdkError(let message):
            return message
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
