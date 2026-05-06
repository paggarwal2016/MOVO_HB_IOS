//
//  CreateCardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 30/04/26.
//

import SwiftUI

struct CreateCardView: View {
    
    var title: String = "Create Card"
    var message: String = "Create a virtual card for instant payments."
    var onTap: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            
            let cardHeight = geo.size.width * 0.42
            
            Button(action: {
                withAnimation(.easeInOut) {
                    onTap()
                }
            }) {
                VStack(spacing: 12) {
                    
                    Spacer(minLength: 8) // ✅ Top spacing
                    
                    // MARK: - Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.primary, .secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50) // ✅ fixed size (stable)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold)) // ✅ reduced
                            .foregroundColor(.white)
                    }
                    
                    // MARK: - Title
                    Text(title)
                        .font(.system(size: 20, weight: .semibold)) // ✅ reduced
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8) // ✅ prevents overflow
                    
                    // MARK: - Message
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .allowsTightening(true)              // ✅ better spacing
                        .minimumScaleFactor(0.9)             // ✅ slight shrink only if needed
                        .frame(maxWidth: .infinity)          // ✅ use full card width
                        .fixedSize(horizontal: false, vertical: true) // ✅ prevents clipping
                        .padding(.horizontal, 12)
                    
                    Spacer(minLength: 8) // ✅ bottom balance
                }
                .frame(maxWidth: .infinity)
                .frame(height: cardHeight)
                
                // MARK: - Background
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(height: UIScreen.main.bounds.width * 0.42)
    }
}
