//
//  AppDelegate.swift
//  MovocashIOS
//
//  Created by Vinu on 31/03/26.
//

import UIKit
import Foundation
import FirebaseCore
import FirebaseMessaging
import UserNotifications


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // 1. Firebase
        FirebaseApp.configure()
        
        // 2. Crashlytics — set user info after login
        
        // 3. Set delegate — permission is requested after login (RootView)
        // Re-register silently if already authorized (returning users)
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized ||
               settings.authorizationStatus == .provisional {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        
        // 4. FCM delegate
        Messaging.messaging().delegate = self
        
        return true
    }
    
    // Pass APNs token → Firebase
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        Messaging.messaging().apnsToken = token
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        SecureLogger.error("APNs registration failed: \(error.localizedDescription)")
    }
    
    // ── MessagingDelegate ───────────────────────────────
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        SecureLogger.debug("FCM Token")
        Task { @MainActor in PushManager.shared.onTokenRefresh(token) }
    }
    
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
