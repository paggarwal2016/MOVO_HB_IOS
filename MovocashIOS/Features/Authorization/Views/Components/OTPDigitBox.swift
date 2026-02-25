//
//  OTPDigitBox.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/02/26.
//

import SwiftUI

struct OTPDigitBox: View {
    
    let digit: String
    let isActive: Bool
    let isFilled: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? Color.blue : Color.gray.opacity(0.4), lineWidth: 1.5)
                .frame(width: 45, height: 55)

            Text(digit)
                .font(.title2)
                .fontWeight(.semibold)
        }
    }
}
