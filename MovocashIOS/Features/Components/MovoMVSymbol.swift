//
//  MovoMVSymbol.swift
//  MovocashIOS
//
//  Created by Vinu on 12/05/26.
//

import Foundation
import SwiftUI

// MARK: - MV Symbol (Canvas-drawn, scales to any size)
public struct MovoMVSymbol: View {
    public var color: Color?
    
    public init(color: Color? = nil) {
        self.color = color
    }
    
    public var body: some View {
        let strokeColor = color ?? Color.movo.textPrimary
        Canvas { context, size in
            // Source coords: 90 × 90 (from the user-provided SVG)
            let s = min(size.width, size.height) / 90.0
            
            // Top V / M stroke
            var top = Path()
            top.move(to: .init(x: 0,      y: 0))
            top.addLine(to: .init(x: 18*s, y: 0))
            top.addLine(to: .init(x: 45*s, y: 24*s))
            top.addLine(to: .init(x: 72*s, y: 0))
            top.addLine(to: .init(x: 90*s, y: 0))
            top.addLine(to: .init(x: 45*s, y: 42*s))
            top.closeSubpath()
            context.fill(top, with: .color(strokeColor))
            
            // Middle V / M stroke
            var mid = Path()
            mid.move(to: .init(x: 0,      y: 34*s))
            mid.addLine(to: .init(x: 18*s, y: 34*s))
            mid.addLine(to: .init(x: 45*s, y: 58*s))
            mid.addLine(to: .init(x: 72*s, y: 34*s))
            mid.addLine(to: .init(x: 90*s, y: 34*s))
            mid.addLine(to: .init(x: 45*s, y: 76*s))
            mid.closeSubpath()
            context.fill(mid, with: .color(strokeColor))
            
            // Left vertical cut / leg
            var left = Path()
            left.move(to: .init(x: 0,      y: 0))
            left.addLine(to: .init(x: 14*s, y: 0))
            left.addLine(to: .init(x: 14*s, y: 76*s))
            left.addLine(to: .init(x: 0,    y: 90*s))
            left.closeSubpath()
            context.fill(left, with: .color(strokeColor))
            
            // Right vertical cut / leg
            var right = Path()
            right.move(to: .init(x: 76*s, y: 0))
            right.addLine(to: .init(x: 90*s, y: 0))
            right.addLine(to: .init(x: 90*s, y: 90*s))
            right.addLine(to: .init(x: 76*s, y: 76*s))
            right.closeSubpath()
            context.fill(right, with: .color(strokeColor))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}




struct AmbientGlowView: View {
    
    var color: Color = .movo.accent
    var size: CGFloat = 400
    var opacity: Double = 0.08
    var blurRadius: CGFloat = 60
    var yOffset: CGFloat = -240
    
    var body: some View {
        color
            .opacity(opacity)
            .frame(width: size, height: size)
            .blur(radius: blurRadius)
            .offset(y: yOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
    }
}
