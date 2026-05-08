//
//  String+Extension.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation

extension String {
    func maskedCardNumber() -> String {
        let clean = self.replacingOccurrences(of: " ", with: "")
        
        guard clean.count >= 8 else { return self }
        
        let first4 = clean.prefix(4)
        let last4 = clean.suffix(4)
        
        return "\(first4) **** **** \(last4)"
    }
}


extension Decimal {
    
    func toString() -> String {
        NSDecimalNumber(decimal: self).stringValue
    }
    
    func toCurrencyString() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "0.00"
    }
}


private func formatUSPhone(_ digits: String) -> String {
    switch digits.count {
    case 0:       return ""
    case 1...3:   return "(\(digits)"
    case 4...6:   return "(\(digits.prefix(3))) \(digits.dropFirst(3))"
    default:      return "(\(digits.prefix(3))) \(digits.dropFirst(3).prefix(3))-\(digits.dropFirst(6))"
    }
}
