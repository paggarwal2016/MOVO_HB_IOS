//
//  ShieldView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 26/02/26.
//

import SwiftUI

struct ShieldView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42))
                Text("Screen Protected")
                    .font(.headline)
                Text("Recording & background capture blocked")
                    .font(.caption)
            }
            .foregroundColor(.white)
        }
    }
}


struct SensitiveScreenModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .onAppear {
                ScreenSecurityManager.shared.sensitiveScreenVisible = true
            }
            .onDisappear {
                ScreenSecurityManager.shared.sensitiveScreenVisible = false
            }
    }
}

extension View {
    func sensitiveScreen() -> some View {
        modifier(SensitiveScreenModifier())
    }
}
