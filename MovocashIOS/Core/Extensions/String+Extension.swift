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
