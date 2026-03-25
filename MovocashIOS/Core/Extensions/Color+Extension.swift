//
//  Color+Extensions.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)         / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension Color {
    
    // MARK: - Primary (Blue)
    static let primaryBlue = Color(red: 0/255, green: 102/255, blue: 204/255)
    static let navyBlue = Color(red: 10/255, green: 31/255, blue: 68/255)
    static let softBlue = Color(red: 102/255, green: 153/255, blue: 255/255)
    
    // MARK: - Success (Green)
    static let successGreen = Color(red: 0/255, green: 200/255, blue: 83/255)
    static let darkGreen = Color(red: 0/255, green: 150/255, blue: 70/255)
    static let lightGreen = Color(red: 102/255, green: 255/255, blue: 178/255)
    
    // MARK: - Background
    static let appBackground = Color(red: 245/255, green: 247/255, blue: 250/255)
    static let cardBackground = Color.white
    static let softBackground = Color(red: 230/255, green: 235/255, blue: 240/255)
    
    // MARK: - Text
    static let primaryText = Color(red: 20/255, green: 20/255, blue: 20/255)
    static let secondaryText = Color(red: 100/255, green: 100/255, blue: 100/255)
    static let mutedText = Color(red: 150/255, green: 150/255, blue: 150/255)
    
    // MARK: - Status
    static let errorRed = Color(red: 220/255, green: 53/255, blue: 69/255)
    static let warningOrange = Color(red: 255/255, green: 159/255, blue: 28/255)
    
    // MARK: - Accent
    static let accentPurple = Color(red: 102/255, green: 51/255, blue: 153/255)
}
