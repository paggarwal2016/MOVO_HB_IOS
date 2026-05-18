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
                                .progressViewStyle(CircularProgressViewStyle(tint: theme.background.color))
                                .scaleEffect(0.8)
                        } else {
                            Text(buttonLabel)
                                .textStyle(Typography.button)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .foregroundStyle(theme.background.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.accent.color)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }

            Spacer(minLength: 8)

            LinkBankIllustration()
                .frame(width: 110, height: 90)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.elevated.color)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                .stroke(theme.border.color, lineWidth: DesignTokens.Stroke.hairline)
        )
    }

    // MARK: - List State

    private var listState: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .textStyle(Typography.cardHero)
                .foregroundStyle(Color.movo.textPrimary)

            VStack(spacing: 0) {
                ForEach(accounts.indices, id: \.self) { index in
                    LinkedAccountRowView(account: accounts[index])
                    if index < accounts.count - 1 {
                        Rectangle()
                            .fill(Color.movo.border)
                            .frame(height: DesignTokens.Stroke.hairline)
                            .padding(.leading, 74)
                    }
                }
            }
            .background(Color.movo.elevatedHigh)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))

            Button(action: onConnectAnother) {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.movo.textSecondary))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Connect another bank")
                            .textStyle(Typography.button)
                    }
                }
                .foregroundStyle(Color.movo.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.lg)
                .background(Color.movo.elevatedHigh)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
                        .stroke(
                            style: StrokeStyle(lineWidth: DesignTokens.Stroke.medium, dash: [6, 4])
                        )
                        .foregroundStyle(Color.movo.borderStrong)
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color.movo.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                .strokeBorder(Color.movo.border, lineWidth: DesignTokens.Stroke.hairline)
        )
    }
}

// MARK: - Link Bank Illustration

private struct LinkBankIllustration: View {
    private let theme = MovoTheme.color

    var body: some View {
        ZStack {
            // Dotted connecting line from bank to phone
            Canvas { ctx, size in
                var path = Path()
                path.move(to: CGPoint(x: size.width * 0.38, y: size.height * 0.58))
                path.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.42))
                ctx.stroke(
                    path,
                    with: .color(MovoTheme.color.accent.color.opacity(0.75)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2.5, 4])
                )
            }

            // Bank building — upper left
            Image(systemName: "building.columns")
                .font(.system(size: 46, weight: .thin))
                .foregroundStyle(theme.textSecondary.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 2, y: 0)

            // Lock icon — right of bank top
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundStyle(theme.accent.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 54, y: 4)

            // Phone — lower right
            phoneView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: -2, y: -2)
        }
    }

    private var phoneView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .stroke(theme.textSecondary.color, lineWidth: 1.5)
                .frame(width: 38, height: 54)

            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.textTertiary.color.opacity(0.5))
                    .frame(width: 24, height: 5)
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.textTertiary.color.opacity(0.5))
                    .frame(width: 24, height: 5)
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.accent.color)
                    .frame(width: 24, height: 7)
            }
            .padding(.vertical, 10)
            .frame(width: 38, height: 54)
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

            VStack(alignment: .trailing, spacing: 2) {
                Text(account.formattedBalance)
                    .textStyle(Typography.body)
                    .foregroundStyle(Color.movo.textPrimary)
                Text("Available")
                    .textStyle(Typography.captionSmall)
                    .foregroundStyle(Color.movo.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var avatarView: some View {
        let initial = account.institutionName.first.map(String.init) ?? "?"
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(account.logoImage != nil ? Color(.systemBackground) : Color.matteBlack)
                .frame(width: 46, height: 46)
            if let logo = account.logoImage {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text(initial.uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray5), lineWidth: account.logoImage != nil ? 1 : 0)
        )
    }
}
