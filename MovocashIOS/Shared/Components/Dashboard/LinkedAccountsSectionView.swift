//
//  LinkedAccountsSectionView.swift
//  MovocashIOS
//

import SwiftUI

struct LinkedAccountsSectionView: View {

    let title: String
    let description: String
    let buttonLabel: String
    let accounts: [ACHAccount]
    let isLoading: Bool
    var isLoadingAccounts: Bool = false
    var onLinkAccount: () -> Void
    var onConnectAnother: () -> Void

    private let theme = MovoTheme.color

    var body: some View {
        if isLoadingAccounts && accounts.isEmpty {
            LinkedAccountSkeleton()
        } else if accounts.isEmpty {
            emptyState
        } else {
            listState
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {

            Text("LINK ACCOUNT")
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.textTertiary)

            VStack(alignment: .leading, spacing: 16) {
                // Title + description + illustration side by side
                HStack(alignment: .center, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .textStyle(Typography.cardHero)
                            .foregroundStyle(theme.textPrimary.color)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(description)
                            .textStyle(Typography.subtitle)
                            .foregroundStyle(theme.textSecondary.color)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LinkBankIllustration()
                        .frame(width: 130, height: 85)
                }

                // Button spans full card width — text always fits on one line
                Button(action: onLinkAccount) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.movo.onAccent))
                            .scaleEffect(0.8)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(buttonLabel)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(MovoPrimaryButtonStyle())
                .disabled(isLoading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient.cardVoid)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                    .strokeBorder(DesignTokens.Palette.silverTint.color.opacity(0.35), lineWidth: DesignTokens.Stroke.hairline)
            )
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - List State

    private var listState: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {

            // Header — sits OUTSIDE the card, like CardSelectorView's section title.
            Text(title.uppercased())
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.textTertiary)

            // Card — only the accounts list + connect-another action carry the surface.
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {

                VStack(spacing: 0) {
                    ForEach(accounts.indices, id: \.self) { index in
                        LinkedAccountRowView(account: accounts[index])
                        if index < accounts.count - 1 {
                            Rectangle()
                                .fill(Color.movo.cardBorder)
                                .frame(height: Stroke.hairline)
                        }
                    }
                }

                Button(action: onConnectAnother) {
                    HStack(spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.movo.textSecondary))
                                .scaleEffect(0.8)
                        } else {
                            Text(buttonLabel.uppercased())
                                .textStyle(Typography.eyebrow)
                                .foregroundColor(Color.movo.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            MovoChevron(.disclosure)
                        }
                    }
                    .padding(.vertical, Spacing.md)
                    .padding(.top, Spacing.sm)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.movo.cardBorder)
                        .frame(height: Stroke.hairline)
                }
            }
            .padding(DesignTokens.Spacing.lg)
            // Match PrimaryAccountContent / BalanceCardView surface — the cardVoid
            // gradient with a silver hairline border.
            .background(LinearGradient.cardVoid)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                    .strokeBorder(DesignTokens.Palette.silverTint.color.opacity(0.35), lineWidth: DesignTokens.Stroke.hairline)
            )
        }
    }
}

// MARK: - Link Bank Illustration

// MARK: - Link Bank Illustration
//
// Canonical 230×150 composition, scales proportionally to fit available space.
// Three layers: bank glyph + connector arc/arrowhead (Canvas), then the Movo M
// with tagline (SwiftUI views) positioned over the Canvas via GeometryReader.

private struct LinkBankIllustration: View {

    var body: some View {
        // Canvas uses its OWN size parameter. Caller supplies an explicit
        // frame(width:height:) so the Canvas always gets concrete dimensions.
        Canvas { context, size in
            let s = size.width / 230.0

            let silver = GraphicsContext.Shading.color(Color.movo.silverTint)
            let accent = GraphicsContext.Shading.color(Color.movo.accent)
            let thin   = StrokeStyle(lineWidth: 2.0 * s, lineCap: .round, lineJoin: .round)
            let thick  = StrokeStyle(lineWidth: 2.5 * s, lineCap: .round, lineJoin: .round)

            // ── Roof (pediment) ────────────────────────────────────────────────
            var roof = Path()
            roof.move(to:    CGPoint(x: 24*s, y: 58*s))
            roof.addLine(to: CGPoint(x: 88*s, y: 58*s))
            roof.addLine(to: CGPoint(x: 56*s, y: 42*s))
            roof.closeSubpath()
            context.stroke(roof, with: silver, style: thin)

            // ── Entablature bar ────────────────────────────────────────────────
            var entab = Path()
            entab.move(to:    CGPoint(x: 28*s, y: 61*s))
            entab.addLine(to: CGPoint(x: 84*s, y: 61*s))
            context.stroke(entab, with: silver, style: thin)

            // ── Columns ───────────────────────────────────────────────────────
            for cx in [38, 56, 74] as [CGFloat] {
                var col = Path()
                col.move(to:    CGPoint(x: cx*s, y: 63*s))
                col.addLine(to: CGPoint(x: cx*s, y: 90*s))
                context.stroke(col, with: silver, style: thin)
            }

            // ── Base (slightly thicker) ────────────────────────────────────────
            var base = Path()
            base.move(to:    CGPoint(x: 26*s, y: 93*s))
            base.addLine(to: CGPoint(x: 86*s, y: 93*s))
            context.stroke(base, with: silver, style: thick)

            // ── Connector arc  Q(94,54)(132,28)(162,62) ──────────────────────
            var arc = Path()
            arc.move(to: CGPoint(x: 94*s, y: 54*s))
            arc.addQuadCurve(
                to:      CGPoint(x: 162*s, y: 62*s),
                control: CGPoint(x: 132*s, y: 28*s)
            )
            context.stroke(arc, with: accent, style: thick)

            // ── Arrowhead at arc tip (162, 62) ─────────────────────────────────
            // Tangent at t=1: 2*(P2−ctrl) = 2*(30,34)  mag≈90.69
            // Wings = reversed unit (−0.6614, −0.7499) rotated ±25°
            let len: CGFloat = 9 * s
            let tip = CGPoint(x: 162*s, y: 62*s)
            let w1  = CGPoint(x: tip.x + (-0.2825) * len, y: tip.y + (-0.9592) * len)
            let w2  = CGPoint(x: tip.x + (-0.9163) * len, y: tip.y + (-0.4002) * len)
            var head = Path()
            head.move(to: w1)
            head.addLine(to: tip)
            head.addLine(to: w2)
            context.stroke(head, with: accent, style: thick)
        }
        // Overlay: GeometryReader here reads the Canvas's resolved size — safe.
        .overlay(alignment: .topLeading) {
            GeometryReader { geo in
                let s = geo.size.width / 230.0
                VStack(spacing: max(1, 3 * s)) {
                    MovoMVSymbol()
                        .frame(width: 44 * s, height: 44 * s)
                    Text("Let\u{2019}s Movo.")
                        .font(.system(size: max(7, 13 * s), weight: .medium).italic())
                        .foregroundColor(Color.movo.textTertiary)
                }
                .position(x: 192 * s, y: 73 * s)
            }
        }
    }
}

// MARK: - Row

struct LinkedAccountRowView: View {

    let account: ACHAccount

    private var maskedNumber: String {
        let last4 = String(account.accountNumber.suffix(4))
        return "•••• \(last4)"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 3) {
                Text("\(account.institutionName) \(account.accountName)")
                    .textStyle(Typography.body)
                    .foregroundStyle(Color.movo.textPrimary)
                    .lineLimit(2)

                Text(maskedNumber)
                    .textStyle(Typography.caption)
                    .foregroundStyle(Color.movo.textTertiary)
            }

            Spacer()

            Text(account.formattedBalance)
                .textStyle(Typography.cardTitle)
                .foregroundStyle(Color.movo.textPrimary)
                .monospacedDigit()
        }
        .padding(.vertical, Spacing.md)
    }

    @ViewBuilder
    private var avatarView: some View {
        let initial = account.institutionName.first.map(String.init) ?? "?"
        ZStack {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(account.logoImage != nil ? Color.movo.elevatedHigh : Color.movo.elevatedHigh)
                .frame(width: 46, height: 46)
            if let logo = account.logoImage {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            } else {
                Text(initial.uppercased())
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Color.movo.textPrimary)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .strokeBorder(Color.movo.border, lineWidth: account.logoImage != nil ? Stroke.hairline : Stroke.hairline)
        )
    }
}
