//
//  CardDetailView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import SwiftUI

struct CardDetailPopupView: View {
    
    let card: VCardsResponse
    @Binding var isPresented: Bool
    @State private var copiedField: String?
    
    private let brandColor = Color(hex: "#C0472B")
    
    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 0) {
                
                ZStack(alignment: .topTrailing) {
                    headerCurve
                    
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.white.opacity(0.25))
                            .clipShape(Circle())
                    }
                    .padding(16)
                }
                
                VStack(spacing: 0) {
                    DetailField(
                        label: "CARD NUMBER",
                        value: card.cardNumber,
                        copiedField: $copiedField,
                        fullWidth: true,
                        accentColor: AppColors.primary
                    )
                    
                    Divider().padding(.horizontal, 20)
                    
                    HStack(alignment: .top, spacing: 0) {
                        PlainField(label: "EXP DATE", value: card.expiration, fullWidth: true)
                        Divider().frame(height: 60)
                        PlainField(label: "ZIP", value: card.lastFour, fullWidth: true)
                    }
                    
                    Divider().padding(.horizontal, 20)
                    
                    PlainField(label: "DESIGN", value: card.name, fullWidth: true)
                }
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 12)
            .padding(.horizontal, 15)
        }
    }
    
    // MARK: - Curved header
    
    private var headerCurve: some View {
        ZStack {
            Color.white
            
            GeometryReader { geo in
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: h - 30))
                    path.addQuadCurve(
                        to: CGPoint(x: 0, y: h - 30),
                        control: CGPoint(x: w / 2, y: h + 20)
                    )
                    path.closeSubpath()
                }
                .fill(AppColors.primary)
            }
            
            VStack(spacing: 6) {
                Text("--")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                
                Text(card.formattedBalance)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("AVAILABLE BALANCE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .tracking(1.5)
            }
            .padding(.vertical, 32)
        }
        .frame(height: 180)
        .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 24))
    }
}


// MARK: - DetailField

struct DetailField: View {
    
    let label: String
    let value: String
    @Binding var copiedField: String?
    var fullWidth: Bool = false
    let accentColor: Color
    
    private var isCopied: Bool { copiedField == label }
    
    var body: some View {
        Button {
            UIPasteboard.general.string = value
            copiedField = label
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if copiedField == label { copiedField = nil }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                }
                
                Spacer()
                
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 18))
                    .foregroundStyle(isCopied ? .green : accentColor)
                    .animation(.spring, value: isCopied)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(.plain)
    }
}


// MARK: - PlainField (no copy, display only)

struct PlainField: View {
    let label: String
    let value: String
    var fullWidth: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
    }
}


// MARK: - RoundedCornersShape

struct RoundedCornersShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}


// MARK: - VCardsResponse extension

extension VCardsResponse {
    var formattedBalance: String {
        return "$20,000.00" // replace with real balance field
    }
}
