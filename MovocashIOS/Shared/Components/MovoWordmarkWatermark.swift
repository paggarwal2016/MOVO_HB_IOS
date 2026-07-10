//
//  MovoWordmarkWatermark.swift
//  MovocashIOS
//

import SwiftUI

struct MovoWordmarkWatermark: View {
    var body: some View {
        Text("MOVOMONEY")
            .font(.system(size: 20, weight: .bold, design: .default))
            .tracking(12)
            .foregroundColor(Color.movo.textPrimary)
    }
}
