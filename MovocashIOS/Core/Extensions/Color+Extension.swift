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
    
    // MARK: - Brand
    static let primary = Color(red: 181/255, green: 49/255, blue: 62/255) // Red
    static let secondary = Color(red: 220/255, green: 223/255, blue: 228/255) // gray
    
    // MARK: - Background
    static let background = UIColor.black
    static let backgroundSwiftUI = Color.black
    
    // MARK: - Labels
    static let primaryText = UIColor.lightGray
    static let secondaryText = UIColor.gray
    
    static let primaryTextSwiftUI = Color(.lightGray)
    static let secondaryTextSwiftUI = Color(.gray)
    
    // MARK: - Input
    static let inputBackground = Color(#colorLiteral(red: 0.9463850856, green: 0.9463850856, blue: 0.9463850856, alpha: 1))
    static let inputText = UIColor.white
    static let inputPlaceholder = UIColor.gray
    
    // MARK: - Accent
    static let accent = UIColor(
        red: 77/255,
        green: 163/255,
        blue: 255/255,
        alpha: 1
    )
    
    static let accent1 = UIColor(red: 181/255, green: 49/255, blue: 62/255, alpha: 1)
    
    // MARK: - Primary (Blue)
    static let primaryBlue = Color(red: 0/255, green: 102/255, blue: 204/255)
    static let navyBlue = Color(red: 10/255, green: 31/255, blue: 68/255)
    static let softBlue = Color(red: 102/255, green: 153/255, blue: 255/255)
    
    // MARK: - Success (Green)
    static let successGreen = Color(red: 0/255, green: 200/255, blue: 83/255)
    static let darkGreen = Color(red: 0/255, green: 150/255, blue: 70/255)
    static let lightGreen = Color(red: 102/255, green: 255/255, blue: 178/255)
    
    // MARK: - Background
    static let cardBackground = Color.white
    static let softBackground = Color(red: 230/255, green: 235/255, blue: 240/255)
    
    // MARK: - Text
    static let mutedText = Color(red: 150/255, green: 150/255, blue: 150/255)
    
    // MARK: - Status
    static let errorRed = Color(red: 220/255, green: 53/255, blue: 69/255)
    static let warningOrange = Color(red: 255/255, green: 159/255, blue: 28/255)
    
    // MARK: - Accent
    static let accentPurple = Color(red: 102/255, green: 51/255, blue: 153/255)
    
    static let preTcolor = Color(#colorLiteral(red: 0.04898288101, green: 0.04898288101, blue: 0.04898288101, alpha: 1))
    
    static let secTcolor = Color(#colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1))
    
    static let appBackground = Color(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1))
    
    static let matteBlack = Color(#colorLiteral(red: 0.1568627451, green: 0.1568627451, blue: 0.168627451, alpha: 1))
}



enum AppColor {
    
    // MARK: - Background
    static let app = Color(hex: "#0C0C0C")
    static let tab = Color(hex: "#0C0C0C")
    
    // Card
    static let card = Color(hex: "#1E1E21")
    
    // MARK: - Surface
    static let surface = Color(hex: "#1A1A1F")
    static let surfaceHover = Color(hex: "#22222A")
    static let surfacePressed = Color(hex: "#2C2C35")
    
    // MARK: - Primary Text / CTA
    static let primary = Color(hex: "#C8CDD6")
    static let primaryHover = Color(hex: "#D6DAE2")
    static let primaryPressed = Color(hex: "#B0B6C0")
    static let primaryDisabled = Color(hex: "#5F636B")
    
    // MARK: - Selection
    static let selectedBackground = Color(hex: "#2C2C35")
    static let selectedText = Color(hex: "#C8CDD6")
    static let selectionOverlay = Color.white.opacity(0.08)
    
    // MARK: - Focus
    static let focusRing = Color(hex: "#F5F6F7")
    
    // MARK: - Highlight
    static let textSelection = Color.white.opacity(0.30)
    static let searchHighlight = Color.white.opacity(0.14)
    
    // MARK: - Destructive
    static let destructive = Color(hex: "#E5484D")
    static let destructivePressed = Color(hex: "#C73237")
    
    // MARK: - Text
    static let primaryText = Color(hex: "#F4F4F8")
    static let secondaryText = Color(hex: "#9D9FA6")
    
    static let white = Color(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1))
}
