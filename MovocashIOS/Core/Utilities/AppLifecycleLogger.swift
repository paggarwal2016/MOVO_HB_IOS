//
//  AppLifecycleLogger.swift
//  MovocashIOS
//

import SwiftUI
import UIKit
import Combine

struct AppLifecycleLogger: ViewModifier {

    let appState: AppState

    @SwiftUI.Environment(\.scenePhase) private var scenePhase

    @State private var backgroundedAt: Date?

    func body(content: Content) -> some View {
        content
            // ── SwiftUI scene phase ────────────────────────────────────────
            .onChangeCompat(of: scenePhase) { phase in
                log("scenePhase → \(describe(phase))")
            }
            // ── Foreground ─────────────────────────────────────────────────
            .onReceive(note(UIApplication.willEnterForegroundNotification)) { _ in
                log("willEnterForeground\(elapsedSuffix())")
            }
            .onReceive(note(UIApplication.didBecomeActiveNotification)) { _ in
                log("didBecomeActive (foreground / active)\(elapsedSuffix())")
                backgroundedAt = nil
            }
            // ── Background ─────────────────────────────────────────────────
            .onReceive(note(UIApplication.willResignActiveNotification)) { _ in
                log("willResignActive")
            }
            .onReceive(note(UIApplication.didEnterBackgroundNotification)) { _ in
                backgroundedAt = Date()
                log("didEnterBackground")
            }
            // ── Sleep / device lock (protected data) ───────────────────────
            .onReceive(note(UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
                log("protectedDataWillBecomeUnavailable (device locking / sleep)")
            }
            .onReceive(note(UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
                log("protectedDataDidBecomeAvailable (device unlocked)")
            }
            // ── Terminal / memory ──────────────────────────────────────────
            .onReceive(note(UIApplication.willTerminateNotification)) { _ in
                log("willTerminate (terminal)")
            }
            .onReceive(note(UIApplication.didReceiveMemoryWarningNotification)) { _ in
                log("didReceiveMemoryWarning")
            }
    }

    // MARK: - Helpers

    private func note(_ name: Notification.Name) -> NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: name)
    }

    private func elapsedSuffix() -> String {
        guard let backgroundedAt else { return "" }
        let elapsed = Date().timeIntervalSince(backgroundedAt)
        return String(format: " | background=%.1fs", elapsed)
    }

    private func describe(_ phase: ScenePhase) -> String {
        switch phase {
        case .active:     return "active (foreground)"
        case .inactive:   return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }

    private func log(_ event: String) {
        MainActor.assumeIsolated {
            SecureLogger.info(
                "[Lifecycle] \(event) | flow=\(appState.flow.rawValue) "
                + "bootstrapDone=\(appState.hasCompletedBootstrap) "
                + "warmupDone=\(appState.warmupCompleted) "
                + "bgScreen=\(appState.backgroundedFlow?.rawValue ?? "nil")",
                category: .general
            )
        }
    }
}

extension View {
    func logAppLifecycle(_ appState: AppState) -> some View {
        modifier(AppLifecycleLogger(appState: appState))
    }
}
