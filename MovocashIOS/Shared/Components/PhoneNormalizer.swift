//
//  PhoneNormalizer.swift
//  MovocashIOS
//

import Foundation

// MARK: - Error

enum PhoneValidationError: Error, LocalizedError {
    case tooShort
    case tooLong
    case invalidCountryCode

    var errorDescription: String? {
        switch self {
        case .tooShort:           return "Enter your 10-digit US phone number"
        case .tooLong:            return "That number is too long"
        case .invalidCountryCode: return "Only US numbers (+1) are supported"
        }
    }
}

// MARK: - Normalizer

enum PhoneNormalizer {

    /// Strips all non-numeric characters from `raw`, then normalizes to E.164.
    ///
    /// - 10 digits                        → `+1<digits>`
    /// - 11 digits starting with `"1"`    → `+<digits>`
    /// - Fewer than 10 digits             → `.failure(.tooShort)`
    /// - 11 digits not starting with `"1"`→ `.failure(.invalidCountryCode)`
    /// - 12+ digits                       → `.failure(.tooLong)`
    static func normalizePhone(_ raw: String) -> Result<String, PhoneValidationError> {
        let digits = raw.filter { $0.isNumber }
        switch digits.count {
        case ..<10:
            return .failure(.tooShort)
        case 10:
            return .success("+1\(digits)")
        case 11:
            guard digits.hasPrefix("1") else {
                return .failure(.invalidCountryCode)
            }
            return .success("+\(digits)")
        default:
            return .failure(.tooLong)
        }
    }
}
