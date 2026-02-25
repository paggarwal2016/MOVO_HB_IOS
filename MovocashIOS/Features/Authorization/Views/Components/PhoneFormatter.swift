//
//  PhoneFormatter.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/02/26.
//

import Foundation

enum PhoneFormatter {

    /// Returns only digits (max 10)
    static func raw(_ text: String) -> String {
        let digits = text.filter { $0.isNumber }
        return String(digits.prefix(10))
    }

    /// Formats 1234567890 -> (123) 456-7890
    static func formatted(_ text: String) -> String {

        let digits = raw(text)
        let count = digits.count

        var result = ""

        if count > 0 {
            result += "("
            result += String(digits.prefix(min(3, count)))
        }

        if count >= 3 {
            result += ") "
            result += String(digits.dropFirst(3).prefix(min(3, count - 3)))
        }

        if count >= 6 {
            result += "-"
            result += String(digits.dropFirst(6).prefix(min(4, count - 6)))
        }

        return result
    }
}
