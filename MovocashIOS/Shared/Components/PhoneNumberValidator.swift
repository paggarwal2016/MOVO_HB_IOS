//
//  PhoneNumberValidator.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation

nonisolated struct PhoneNumberValidator {

    // MARK: - Sanitize
    // Strip everything except digits, then drop a leading country code
    // so we always work with a clean 10-digit local number.
    static func sanitize(_ input: String) -> String {
        var digits = input.filter { $0.isNumber }

        // Drop leading "1" (US country code) if user typed 11 digits
        if digits.count == 11, digits.hasPrefix("1") {
            digits = String(digits.dropFirst())
        }

        return digits
    }

    // MARK: - Validate (NANP rules)
    // • Exactly 10 digits
    // • Area code (digits 1-3):  first digit 2-9, second digit 0-9 (any)
    // • Exchange   (digits 4-6): first digit 2-9, not 555 (information line)
    // • Subscriber (digits 7-10): no restriction
    static func isValidUSNumber(_ number: String) -> Bool {
        guard number.count == 10, number.allSatisfy({ $0.isNumber }) else {
            return false
        }

        let areaCode     = String(number.prefix(3))
        let exchange     = String(number.dropFirst(3).prefix(3))

        // Area code: first digit must be 2-9
        guard let areaFirst = areaCode.first?.wholeNumberValue,
              areaFirst >= 2 else { return false }

        // Exchange: first digit must be 2-9
        guard let exchFirst = exchange.first?.wholeNumberValue,
              exchFirst >= 2 else { return false }

        // Block 555-0100–555-0199 (fictitious / unassigned)
        if areaCode != "555", exchange == "555" { return false }

        // Block N11 codes as area codes (211, 311, 411 …911)
        if areaCode.dropFirst().hasPrefix("11") { return false }

        return true
    }

    // MARK: - Normalize  →  +1XXXXXXXXXX
    static func normalize(_ number: String) -> String {
        "+1\(number)"
    }

    // MARK: - Format for display  →  (XXX) XXX-XXXX
    static func format(_ number: String) -> String {
        let d = number.filter { $0.isNumber }
        guard d.count == 10 else { return number }
        let area  = d.prefix(3)
        let mid   = d.dropFirst(3).prefix(3)
        let last  = d.dropFirst(6)
        return "(\(area)) \(mid)-\(last)"
    }
}
