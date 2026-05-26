//
//  NetworkBannerView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/03/26.
//

import SwiftUI

// MARK: - Network Banner

struct NetworkBannerView: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: isConnected ? "wifi" : "wifi.slash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isConnected ? Color.green : Color.white)

            Text(isConnected ? "Back online" : "No internet connection")
                .textStyle(Typography.bodyCompact)
                .foregroundStyle(Color.white)

            Spacer()

            if !isConnected {
                OfflinePulseDot()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color.movo.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isConnected ? Color.green.opacity(0.5) : Color.white.opacity(0.15))
                .frame(height: Stroke.thin)
        }
    }
}

// MARK: - Pulse dot (offline indicator)

private struct OfflinePulseDot: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 6, height: 6)
            .opacity(pulsing ? 0.35 : 1.0)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}


// MARK: - Network Modifier

struct NetworkMonitorModifier: ViewModifier {

    @ObservedObject var appState: AppState

    @State private var didReceiveInitialStatus = false
    @State private var showReconnectedBanner = false
    @State private var reconnectedTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if appState.networkStatus == .disconnected {
                NetworkBannerView(isConnected: false)
                    .transition(
                        .move(edge: .top).combined(with: .opacity)
                    )
                    .zIndex(100)
            } else if showReconnectedBanner {
                NetworkBannerView(isConnected: true)
                    .transition(
                        .move(edge: .top).combined(with: .opacity)
                    )
                    .zIndex(100)
            }
        }
        .onReceive(NetworkMonitor.shared.$status) { newStatus in
            // Suppress animation on the very first publish (app cold start) to avoid
            // a banner flash when the path monitor reports initial state.
            guard didReceiveInitialStatus else {
                appState.networkStatus = newStatus
                didReceiveInitialStatus = true
                return
            }

            let wasDisconnected = appState.networkStatus == .disconnected

            withAnimation(.easeInOut(duration: DesignTokens.Motion.standard)) {
                appState.networkStatus = newStatus
            }

            // Show "Back online" briefly when connection is restored.
            if wasDisconnected && newStatus == .connected {
                reconnectedTask?.cancel()
                withAnimation(.easeInOut(duration: DesignTokens.Motion.standard)) {
                    showReconnectedBanner = true
                }
                reconnectedTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: DesignTokens.Motion.standard)) {
                        showReconnectedBanner = false
                    }
                }
            }
        }
    }
}
