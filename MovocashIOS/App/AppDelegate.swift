//
//  AppDelegate.swift
//  MovocashIOS
//
//  Created by Movo Developer on 31/03/26.
//

import UIKit
import Foundation
import FirebaseCore
// FIREBASE PUSH: Re-enable when push notifications are ready.
// Step 1 — uncomment the import below:
// import FirebaseMessaging
import UserNotifications


// FIREBASE PUSH: When re-enabling, restore MessagingDelegate to the conformance list:
// class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Active anti-debug — instruct the kernel to refuse debugger attachment,
        // as early as possible in the launch path. No-op on simulator / DEBUG.
        JailbreakDetector.denyDebugger()

        // 0. Wipe auth state on fresh install — keychain survives uninstall, UserDefaults
        // does not. Also invoked at the top of MovocashIOSApp.init() (before routing);
        // the hasLaunchedBefore guard makes this call a no-op on that second path.
        AppDelegate.clearOnFreshInstallIfNeeded()

        // 1. Firebase core (Analytics only — Crashlytics/Messaging intentionally disabled)
        FirebaseApp.configure()
        Task { @MainActor in
            AnalyticsManager.shared.configureDefaults()
            AnalyticsManager.shared.reapplyIdentity()
        }

        // 3. Crashlytics — set user info after login

        // 4. Set delegate — permission is requested after login (RootView)
        // Re-register silently if already authorized (returning users)
        // FIREBASE PUSH:
//        UNUserNotificationCenter.current().delegate = self
//        Task { @MainActor in
//            let settings = await UNUserNotificationCenter.current().notificationSettings()
//            if settings.authorizationStatus == .authorized ||
//               settings.authorizationStatus == .provisional {
//                UIApplication.shared.registerForRemoteNotifications()
//            }
//        }

        // FIREBASE PUSH: Re-enable when push notifications are ready.
        // Step 2 — uncomment the line below to wire FCM delegate:
        // Messaging.messaging().delegate = self

        return true
    }

    // MARK: - Fresh Install

    /// Wipes auth state on a fresh install (Keychain survives uninstall, UserDefaults
    /// does not). Idempotent and `static` so it can run at the very start of
    static func clearOnFreshInstallIfNeeded() {
        let flagKey = "app.hasLaunchedBefore"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        // Wipe all app Keychain entries except device_id. This is a superset of
        // clearAuthTokens() and also removes per-user biometric enrollment flags
        // (biometric_enrolled_<userId>) that persist across uninstalls and otherwise
        // cause the login flow to incorrectly route returning users to the enrollment
        // screen after a fresh install.
        KeychainManager.shared.clearAllExceptDeviceId()
        RSAKeyManager.shared.deleteKeyPair()
        try? PasscodeManager().clearAll()

        UserDefaults.standard.set(true, forKey: flagKey)
    }

    // FIREBASE PUSH: Re-enable when push notifications are ready.
    // Step 3 — uncomment the method below to forward APNs token to Firebase:
    // func application(_ application: UIApplication,
    //                  didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    //     Messaging.messaging().apnsToken = token
    // }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        SecureLogger.error("APNs registration failed: \(error.localizedDescription)")
    }

    // FIREBASE PUSH: Re-enable when push notifications are ready.
    // Step 4 — uncomment the MessagingDelegate method below:
    // func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    //     guard let token = fcmToken else { return }
    //     SecureLogger.debug("FCM Token")
    //     Task { @MainActor in PushManager.shared.onTokenRefresh(token) }
    // }

    // ── UNUserNotificationCenterDelegate ────────────────

    // App in foreground — show banner
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        Task { @MainActor in PushManager.shared.handle(userInfo: userInfo, source: .foreground) }
        handler([.banner, .sound, .badge])
    }

    // User tapped notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler handler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in PushManager.shared.handle(userInfo: userInfo, source: .tap) }
       //TODO: - Task { @MainActor in DeepLinkRouter.shared.routeFromPush(userInfo: userInfo) }
        handler()
    }

    // Clear badge when user opens app
    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in PushManager.shared.clearBadgeOnActive() }
    }

    // Force fresh TCP connections on a background → foreground transition. While
    // backgrounded, iOS silently drops the app's sockets; reusing a dead keep-alive
    func applicationWillEnterForeground(_ application: UIApplication) {
        Task { await NetworkService.shared.flushConnections() }
    }

    // Background / silent push
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in
            PushManager.shared.handle(userInfo: userInfo, source: .background)
            completionHandler(.newData)
        }
    }
}
