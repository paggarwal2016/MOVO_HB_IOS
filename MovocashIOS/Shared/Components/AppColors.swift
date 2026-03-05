//
//  AppColors.swift
//  MovocashIOS
//
//  Created by Vinu on 02/03/26.
//

import SwiftUI

struct AppColors {
    
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
    static let inputBackground = UIColor(white: 0.12, alpha: 1)
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
}
