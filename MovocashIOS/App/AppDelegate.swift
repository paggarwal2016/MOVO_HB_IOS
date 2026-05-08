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

        // 0. Wipe auth state on fresh install — keychain survives uninstall, UserDefaults does not
        clearOnFreshInstall()

        // 1. Firebase core (Analytics, Crashlytics — always active)
        FirebaseApp.configure()
        // 2. Analytics
        Task { @MainActor in AnalyticsManager.shared.reapplyIdentity() }

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

    private func clearOnFreshInstall() {
        let flagKey = "app.hasLaunchedBefore"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        KeychainManager.shared.clearAuthTokens()
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
