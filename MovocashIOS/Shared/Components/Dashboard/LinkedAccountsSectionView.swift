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
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .textStyle(Typography.cardHero)
                    .foregroundStyle(theme.textPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)

                Text(description)
                    .textStyle(Typography.subtitle)
                    .foregroundStyle(theme.textSecondary.color)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onLinkAccount) {
                    HStack(spacing: 6) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.movo.onAccent))
                                .scaleEffect(0.8)
                        } else {
                            Text(buttonLabel)
                                .textStyle(Typography.button)
                                .lineLimit(1)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftAccentButtonStyle())
                .disabled(isLoading)
            }

            Spacer(minLength: 2)

            LinkBankIllustration()
                .frame(width: 80, height: 65)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.movo.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                .stroke(theme.borderStrong.color, lineWidth: DesignTokens.Stroke.hairline)
        )
    }

    // MARK: - List State

    private var listState: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Color.movo.textTertiary)

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
                        Text(buttonLabel)
                            .textStyle(Typography.body)
                            .foregroundStyle(Color.movo.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.movo.accent)
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
        .background(Color.movo.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                .strokeBorder(Color.movo.borderStrong, lineWidth: DesignTokens.Stroke.hairline)
        )
    }
}

// MARK: - Link Bank Illustration

private struct LinkBankIllustration: View {
    private let theme = MovoTheme.color

    var body: some View {
        ZStack {
            // Dotted connecting line
            Canvas { ctx, size in
                var path = Path()
                path.move(to: CGPoint(x: size.width * 0.38, y: size.height * 0.52))
                path.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.50))

                ctx.stroke(
                    path,
                    with: .color(theme.accent.color.opacity(0.75)),
                    style: StrokeStyle(
                        lineWidth: 1.2,
                        lineCap: .round,
                        dash: [2, 3]
                    )
                )
            }

            // Bank
            Image(systemName: "building.columns")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(theme.textSecondary.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(y: -4)

            // Lock
            Image(systemName: "lock.fill")
                .font(.system(size: 8))
                .foregroundStyle(theme.accent.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 38, y: -2)

            // Phone
            phoneView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(y: 4)
        }
        .frame(width: 80, height: 70)
    }

    private var phoneView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.textSecondary.color, lineWidth: 1.2)
                .frame(width: 28, height: 42)

            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.textTertiary.color.opacity(0.5))
                    .frame(width: 16, height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.textTertiary.color.opacity(0.5))
                    .frame(width: 16, height: 4)

                Spacer()

                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.accent.color)
                    .frame(width: 16, height: 6)
            }
            .padding(.vertical, 8)
            .frame(width: 28, height: 42)
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
