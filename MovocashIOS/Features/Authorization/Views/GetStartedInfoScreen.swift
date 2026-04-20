//
//  GetStartedInfoScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/04/26.
//

import SwiftUI

struct GetStartedInfoScreen: View {

    let onReady: () -> Void
    let onNotNow: () -> Void
    let onBack: () -> Void

    private let requirements: [String] = [
        "Be 18 or older",
        "Be a US resident",
        "Have a US mobile number",
        "Be a US tax resident"
    ]

    private let legalItems: [(icon: String, title: String)] = [
        ("lock.shield",          "Privacy Policy"),
        ("creditcard",           "Fee Information"),
        ("checkmark.shield",     "FDIC Protection")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Back + Help
                HStack {
                    BackButton { onBack() }
                    Spacer()
                    Button("Help") {}
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }

                // Title
                Text("Let's get started")
                    .titleStyle()

                // Requirements
                VStack(alignment: .leading, spacing: 6) {
                    Text("To use Movo, you must:")
                        .font(.subheadline)
                        .foregroundColor(.secTcolor)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(requirements, id: \.self) { item in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                                Text(item)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.preTcolor)
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                Divider()

                // Legal info section
                VStack(alignment: .leading, spacing: 0) {
                    Text("Legal info")
                        .font(.subheadline)
                        .foregroundColor(.secTcolor)
                        .padding(.bottom, 12)

                    VStack(spacing: 0) {
                        ForEach(legalItems, id: \.title) { item in
                            Button {
                                // navigate to legal doc
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(.preTcolor)
                                        .frame(width: 24)
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.preTcolor)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secTcolor)
                                }
                                .padding(.vertical, 16)
                            }
                            Divider()
                        }
                    }
                }

                // Photo ID info card
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You'll need photo ID")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.preTcolor)
                        Text("Please have your passport, driver's license, or state ID handy.")
                            .font(.system(size: 13))
                            .foregroundColor(.secTcolor)
                    }
                }
                .padding(14)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Buttons
                VStack(spacing: 12) {
                    PrimaryButton(title: "I'm ready") {
                        onReady()
                    }

                    Button("Not now") {
                        onNotNow()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary, lineWidth: 1.5)
                    )
                }
            }
            .padding()
        }
    }
}
