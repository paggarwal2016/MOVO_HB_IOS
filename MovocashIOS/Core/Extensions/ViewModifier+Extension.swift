//
//  ViewModifier+Extensions.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/04/26.
//

import Foundation
import SwiftUI

// Define once
struct TitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(Color.preTcolor)
    }
}

struct SubtitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 18, weight: .regular))
            .foregroundColor(Color.secTcolor)
    }
}
