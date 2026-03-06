//
//  PhoneNumberValidator.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation

struct PhoneNumberValidator {
    
    static func sanitize(_ input: String) -> String {
        input.filter { $0.isNumber }
    }
    
    static func isValidUSNumber(_ number: String) -> Bool {
        let regex = #"^[2-9][0-9]{9}$"#
        return number.range(of: regex, options: .regularExpression) != nil
    }
    
    static func normalize(_ number: String) -> String {
        "+1\(number)"
    }
}
