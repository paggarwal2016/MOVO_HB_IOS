//
//  AppearanceSettingsView.swift
//  MovocashIOS
//
//  Pushed from the Me tab's PREFERENCES section. Lets the user pick
//  System / Light / Dark. Selection is applied app-wide immediately
//  via the @AppStorage binding that the root .preferredColorScheme reads.
//

import SwiftUI

struct AppearanceSettingsView: View {

    @AppStorage("appearancePreference") private var appearance: Appearance = .system
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            MovoBackground()
            VStack(spacing: 0) {
                navBar
                List {
                    Section {
                        ForEach(Appearance.allCases, id: \.self) { option in
                            Button { appearance = option } label: { optionRow(option) }
                            .buttonStyle(.plain)
                        }
                    } footer: {
                        Text(appearance.footer)
                            .foregroundStyle(Color.movo.textTertiary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            StatusBarScrim()
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            CircularNavButton(systemName: "chevron.left") { dismiss() }
            Spacer()
            Text("Appearance")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Row

    private func optionRow(_ option: Appearance) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(Color.movo.accent)
                    .frame(width: 32, height: 32)
                Image(systemName: option.icon)
                    .font(Typography.body.font)
                    .foregroundStyle(Color.movo.onAccent)
            }
            Text(option.label)
                .font(Typography.body.font)
                .foregroundStyle(Color.movo.textPrimary)
            Spacer()
            if appearance == option {
                Image(systemName: "checkmark")
                    .font(Typography.button.font)
                    .foregroundStyle(Color.movo.accent)
            }
        }
        .contentShape(Rectangle())
    }
}
