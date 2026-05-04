//
//  Font+Extension.swift
//  MovocashIOS
//
//  Created by Vinu on 04/05/26.
//

import Foundation
import SwiftUI

enum AppFont {
    
    // MARK: - Eyebrow
    static let eyebrow = Font.custom("Montserrat-Medium", size: 10)
    
    // MARK: - Balance
    static let balance = Font.custom("Montserrat-SemiBold", size: 28)
    
    // MARK: - Hero
    static let hero = Font.custom("Montserrat-SemiBold", size: 18)
    
    // MARK: - Body
    static let body = Font.custom("Montserrat-Regular", size: 12)
    
    // MARK: - Quick Action
    static let quickAction = Font.custom("Montserrat-SemiBold", size: 10)
    
    // MARK: - CTA
    static let cta = Font.custom("Montserrat-SemiBold", size: 11)
    
    // MARK: - Card Name
    static let cardName = Font.custom("Montserrat-Medium", size: 11)
    
    // MARK: - Section Header
    static let sectionHeader = Font.custom("Montserrat-Medium", size: 9)
    
    // MARK: - Greeting
    static let greetingSubtitle = Font.custom("Montserrat-Medium", size: 9)
    static let greetingName = Font.custom("Montserrat-Medium", size: 13)
    
    // MARK: - Bottom Nav
    static let tabLabel = Font.custom("Montserrat-Medium", size: 9)
    
    // MARK: - Activity
    static let activityName = Font.custom("Montserrat-Medium", size: 12)
    
    static let activityAmount = Font.system(size: 14, weight: .medium) // ⚠️ keep system for numbers
    
    // MARK: - Card Number
    static let cardNumber = Font.system(size: 9, weight: .regular, design: .monospaced)
}

struct Tracking {
    static func value(_ em: Double, size: CGFloat) -> CGFloat {
        return em * size
    }
}

extension Font {
    enum MontserratWeight: String {
        case regular  = "Montserrat-Regular"
        case medium   = "Montserrat-Medium"
        case semiBold = "Montserrat-SemiBold"
        case bold     = "Montserrat-Bold"
    }

    static func montserrat(_ weight: MontserratWeight = .regular, size: CGFloat) -> Font {
        Font.custom(weight.rawValue, size: size)
    }
}


extension Text {
    
    @ViewBuilder
    func appStyle(_ style: AppTextStyle) -> some View {
        switch style {
            
        case .eyebrow:
            self
                .font(AppFont.eyebrow)
                .tracking(Tracking.value(0.08, size: 10))
                .textCase(.uppercase)
            
        case .balance:
            self
                .font(AppFont.balance)
                .tracking(Tracking.value(-0.02, size: 28))
                .monospacedDigit()
            
        case .hero:
            self
                .font(AppFont.hero)
                .tracking(Tracking.value(-0.01, size: 18))
            
        case .body:
            self
                .font(AppFont.body)
            
        case .quickAction:
            self
                .font(AppFont.quickAction)
                .tracking(Tracking.value(0.04, size: 10))
                .textCase(.uppercase)
            
        case .cta:
            self
                .font(AppFont.cta)
                .tracking(Tracking.value(0.02, size: 11))
            
        case .cardName:
            self
                .font(AppFont.cardName)
            
        case .sectionHeader:
            self
                .font(AppFont.sectionHeader)
                .tracking(Tracking.value(0.08, size: 9))
                .textCase(.uppercase)
            
        case .greetingSubtitle:
            self
                .font(AppFont.greetingSubtitle)
                .tracking(Tracking.value(0.08, size: 9))
                .textCase(.uppercase)
            
        case .greetingName:
            self
                .font(AppFont.greetingName)
            
        case .tabLabel:
            self
                .font(AppFont.tabLabel)
            
        case .activityName:
            self
                .font(AppFont.activityName)
            
        case .activityAmount:
            self
                .font(AppFont.activityAmount)
                .monospacedDigit()
            
        case .cardNumber:
            self
                .font(AppFont.cardNumber)
                .tracking(Tracking.value(0.16, size: 9))
        }
    }
}


enum AppTextStyle {
    case eyebrow
    case balance
    case hero
    case body
    case quickAction
    case cta
    case cardName
    case sectionHeader
    case greetingSubtitle
    case greetingName
    case tabLabel
    case activityName
    case activityAmount
    case cardNumber
}


//Text("AVAILABLE BALANCE")
//    .appStyle(.eyebrow)
//
//Text("₹ 50.00")
//    .appStyle(.balance)
//
//Text("Amazon")
//    .appStyle(.activityName)

//Font.montserrat("Montserrat-SemiBold", size: 18)
