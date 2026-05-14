//
//  BasePopupView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import SwiftUI

// MARK: - Mode

enum BasePopupMode {
    case simple
    case balance(nickName: String, formattedBalance: String, balanceLabel: String)
}

// MARK: - BasePopupView

struct BasePopupView<Content: View, HeaderTrailing: View>: View {

    let mode: BasePopupMode
    @Binding var isPresented: Bool
    @ViewBuilder let headerTrailing: HeaderTrailing
    @ViewBuilder let content: Content

    init(
        mode: BasePopupMode,
        isPresented: Binding<Bool>,
        @ViewBuilder headerTrailing: () -> HeaderTrailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.mode = mode
        self._isPresented = isPresented
        self.headerTrailing = headerTrailing()
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {

                // MARK: Header
                switch mode {
                case .balance(let nickName, let formattedBalance, let balanceLabel):
                    ZStack(alignment: .topTrailing) {
                        headerCurve(nickName: nickName, formattedBalance: formattedBalance, balanceLabel: balanceLabel)
                        HStack(spacing: 8) {
                            headerTrailing
                            closeButton(foreground: .white, background: .white.opacity(0.25))
                        }
                        .padding(16)
                    }

                case .simple:
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            headerTrailing
                            closeButton(foreground: Color.movo.textPrimary, background: Color.movo.elevatedHigh)
                        }
                    }
                    .padding(16)
                }

                // MARK: Content
                VStack(spacing: 0) { content }
                    .padding(.bottom, 8)
            }
            .background(Color.movo.elevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sheet))
            .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 12)
            .padding(.horizontal, 15)
        }
    }

    // MARK: - Close Button

    private func closeButton(foreground: Color, background: Color) -> some View {
        Button { isPresented = false } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(foreground)
                .padding(8)
                .background(background)
                .clipShape(Circle())
        }
    }

    // MARK: - Header Curve

    private func headerCurve(nickName: String, formattedBalance: String, balanceLabel: String) -> some View {
        Color.movo.accent
            .overlay {
                VStack(spacing: 6) {
                    if !nickName.isEmpty {
                        Text(nickName)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text(formattedBalance)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                    Text(balanceLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .tracking(1.5)
                }
                .padding(.vertical, 32)
            }
            .frame(height: 165)
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
                        .foregroundStyle(Color.movo.textPrimary)

                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.movo.textTertiary)
                        .tracking(1.2)
                }

                Spacer()

                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 18))
                    .foregroundStyle(isCopied ? Color.movo.success : accentColor)
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
                .foregroundStyle(Color.movo.textPrimary)

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.movo.textTertiary)
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
