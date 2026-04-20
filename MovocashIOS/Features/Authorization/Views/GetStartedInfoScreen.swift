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
        ("doc.plaintext",        "Privacy Policy"),
        ("doc.plaintext",        "Terms of Use Agreement"),
        ("signature",            "Electronic Consent")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Back + Help
                HStack {
                    BackButton { onBack() }
                    Spacer()
                }

                // Title
                Text("Accept Terms to continue")
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

                Spacer().frame(height: 28)

                // Buttons
                VStack(spacing: 12) {
                    PrimaryButton(title: "Accept & Continue") {
                        onReady()
                    }
                }
            }
            .padding()
        }
    }
}
