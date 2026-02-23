//
//  OTPTextField.swift
//  MovocashIOS
//
//  Created by Vinu on 23/02/26.
//

import SwiftUI

struct OTPTextField: View {
    @Binding var code: String
    
    var body: some View {
        ZStack {
            HStack(spacing: 16) {
                ForEach(0..<6, id: \.self) { index in
                    VStack {
                        Text(digit(at: index))
                            .font(.title)
                            .frame(width: 30, height: 40)
                        
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(index < code.count ? .blue : .gray.opacity(0.4))
                    }
                }
            }
            
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .foregroundColor(.clear)
                .accentColor(.clear)
                .onChange(of: code) { newValue in
                    if newValue.count > 6 {
                        code = String(newValue.prefix(6))
                    }
                }
        }
    }
    
    private func digit(at index: Int) -> String {
        if index < code.count {
            let stringIndex = code.index(code.startIndex, offsetBy: index)
            return String(code[stringIndex])
        }
        return ""
    }
}
