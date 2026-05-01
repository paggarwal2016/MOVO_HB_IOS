//
//  PushManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 31/03/26.
//

import Foundation
import UserNotifications
import UIKit
// FIREBASE PUSH: Re-enable when push notifications are ready.
// Step 5 — uncomment the import below:
// import FirebaseMessaging
import Combine
import SwiftUI

enum PushSource { case foreground, background, tap }

@MainActor
class PushManager: ObservableObject {
    static let shared = PushManager()

    private let unreadCountKey = "pushUnreadCount"

    @Published var fcmToken: String = ""
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var messages: [PushMessage] = []
    @Published var unreadCount: Int
    @Published var latestMessage: PushMessage?

    private init() {
        unreadCount = UserDefaults.standard.integer(forKey: "pushUnreadCount")
    }

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            await refreshPermissionStatus()
        } catch {
            SecureLogger.error("Push permission request")
        }
    }

    func refreshPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    // ── Token ────────────────────────────────────────────

    func onTokenRefresh(_ token: String) {
        fcmToken = token
        UserDefaults.standard.set(token, forKey: "fcmToken")
        uploadTokenToServer(token)
        subscribeToDefaultTopics()
    }

    func fetchToken() async {
        // FIREBASE PUSH: Re-enable when push notifications are ready.
        // Step 6 — uncomment the block below to fetch the FCM token:
        // do {
        //     let token = try await Messaging.messaging().token()
        //     fcmToken = token
        //     UserDefaults.standard.set(token, forKey: "fcmToken")
        // } catch {
        //     SecureLogger.error("FCM token fetch")
        // }
    }

    func deleteTokenOnLogout() async {
        // FIREBASE PUSH: Re-enable when push notifications are ready.
        // Step 7 — uncomment the FCM block below to delete the token on logout:
        // do {
        //     try await Messaging.messaging().deleteToken()
        //     ["transactions", "alerts", "promotions", "market_updates"].forEach {
        //         Messaging.messaging().unsubscribe(fromTopic: $0) { _ in }
        //     }
        // } catch {
        //     SecureLogger.error("Token delete on logout")
        // }

        fcmToken = ""
        UserDefaults.standard.removeObject(forKey: "fcmToken")
    }

    // ── Handle payload ───────────────────────────────────

    func handle(userInfo: [AnyHashable: Any], source: PushSource) {
        let msg = PushMessage(userInfo: userInfo)
        messages.insert(msg, at: 0)
        latestMessage = msg

        switch source {
        case .foreground:
            updateBadge(to: unreadCount + 1)
        case .background:
            if let aps = userInfo["aps"] as? [String: Any],
               let badge = aps["badge"] as? Int {
                updateBadge(to: badge)
            }
        case .tap:
            break
        }

        SecureLogger.debug("Push received: type=\(msg.type.rawValue) source=\(source)")
    }

    // Called from AppDelegate.applicationDidBecomeActive
    func clearBadgeOnActive() {
        updateBadge(to: 0)
    }

    // ── Private ──────────────────────────────────────────

    private func updateBadge(to count: Int) {
        unreadCount = count
        UserDefaults.standard.set(count, forKey: unreadCountKey)
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }

    private func subscribeToDefaultTopics() {
        // FIREBASE PUSH: Re-enable when push notifications are ready.
        // Step 8 — uncomment the block below to subscribe to default FCM topics:
        // ["transactions", "alerts", "promotions", "market_updates"].forEach {
        //     Messaging.messaging().subscribe(toTopic: $0) { _ in }
        // }
    }

    func subscribe(to topic: String) {
        // FIREBASE PUSH: Re-enable when push notifications are ready.
        // Step 9 — uncomment the block below to subscribe to a topic:
        // Messaging.messaging().subscribe(toTopic: topic) { error in
        //     if let error {
        //         SecureLogger.error("Subscribe: \(topic), Error: \(error)")
        //     }
        // }
    }

    func unsubscribe(from topic: String) {
        // FIREBASE PUSH: Re-enable when push notifications are ready.
        // Step 10 — uncomment the line below to unsubscribe from a topic:
        // Messaging.messaging().unsubscribe(fromTopic: topic)
    }

    // ── UI helpers ───────────────────────────────────────

    func markAllRead() { updateBadge(to: 0) }

    func clearAll() {
        messages.removeAll()
        updateBadge(to: 0)
    }

    private func uploadTokenToServer(_ token: String) {
        // API Call update the token to server
    }
}
