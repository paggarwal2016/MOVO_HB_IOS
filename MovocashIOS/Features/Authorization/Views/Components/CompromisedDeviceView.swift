//
//  CompromisedDeviceView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 24/02/26.
//

import SwiftUI

/// Full-screen hard block shown when `JailbreakDetector` flags the device.
/// Presented as a top-most overlay by `RootView`, so it covers the entire app
/// and intercepts all touches — the app is genuinely disabled while visible.
struct CompromisedDeviceView: View {

    /// Re-runs detection. Returns `true` if the device is still compromised.
    /// `RootView` uses the result to either terminate the app (still compromised)
    /// or dismiss the block (clean — only possible across a relaunch, since a
    /// positive result is cached for the session).
    let onRetry: () async -> Bool

    @State private var isChecking = false

    var body: some View {
        ZStack {
            // Opaque base so nothing behind the block can show through.
            Color.movo.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.red)

                Text("Security Risk Detected")
                    .font(.title2)
                    .bold()

                Text("Your device appears to be jailbroken or rooted. For your safety, the app is disabled.")
                    .multilineTextAlignment(.center)
                    .padding()

                Button {
                    guard !isChecking else { return }
                    Task {
                        isChecking = true
                        _ = await onRetry()
                        isChecking = false
                    }
                } label: {
                    Text(isChecking ? "Checking…" : "Retry Check")
                }
                .buttonStyle(MovoPrimaryButtonStyle())
                .disabled(isChecking)
                .padding(.horizontal)
            }
            .padding()
        }
        // Belt-and-suspenders: block any touch from reaching views behind the overlay.
        .contentShape(Rectangle())
    }
}

#Preview {
    CompromisedDeviceView(onRetry: { true })
}
