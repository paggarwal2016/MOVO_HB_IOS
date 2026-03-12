//
//  CardSkeletonView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation
import SwiftUI

// MARK: - CardSkeletonView.swift

struct CardSkeletonView: View {
    @State private var shimmer = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.gray.opacity(0.2))
            
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.15), .clear],
                        startPoint: shimmer ? .topLeading : .bottomTrailing,
                        endPoint:   shimmer ? .bottomTrailing : .topLeading
                    )
                )
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: shimmer)
        }
        .frame(height: 200)
        .padding(.horizontal)
        .onAppear { shimmer = true }
    }
}
