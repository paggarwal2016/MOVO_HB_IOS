//
//  PushManager.swift
//  MovocashIOS
//
//  Created by Vinu on 31/03/26.
//

import Foundation
import UserNotifications
import UIKit
import FirebaseMessaging
import Combine
import SwiftUI

enum PushSource { case foreground, background, tap}

@MainActor
class PushManager: ObservableObject {
    static let shared = PushManager()
    private init() {}
    
    @Published var fcmToken: String = ""
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var messages: [PushMessage] = []
    @Published var unreadCount: Int = 0
    @Published var latestMessage: PushMessage?
    
    
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            await refreshPermissionStatus()
            // AnalyticsManager.shared.logPushPermission
        } catch {
            // CrashlyticsManager.shared.record("Push permission request")
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
        subscribleToDefaultTopics()
    }
    
    func fetchToken() async {
        do {
            let token = try await Messaging.messaging().token()
            fcmToken  = token
        } catch {
            //CrashlyticsManager.shared.record
            SecureLogger.error("FCM token fetch")
        }
    }
    
    func deleteTokenOnLogout() async {
        do {
            try await Messaging.messaging().deleteToken()
            fcmToken = ""
            UserDefaults.standard.removeObject(forKey: "fcmToken")
            ["transactions", "alerts", "promotions", "market_updates"].forEach {
                Messaging.messaging().unsubscribe(fromTopic: $0) { _ in }
            }
        } catch {
            //CrashlyticsManager.shared.record
            SecureLogger.error("Token delete on logout")
        }
    }
    
    
    // ── Handle payload ───────────────────────────────────
    func handle(userInfo: [AnyHashable: Any], source: PushSource) {
        let msg = PushMessage(userInfo: userInfo)
        messages.insert(msg, at: 0)
        latestMessage = msg
        if source == .foreground { unreadCount += 1 }
        //        CrashlyticsManager.shared.log
        SecureLogger.debug("Push received: type=\(msg.type.rawValue) source=\(source)")
    }
    
    private func subscribleToDefaultTopics() {
        ["transactions", "alerts", "promotions", "market_updates"].forEach {
            Messaging.messaging().subscribe(toTopic: $0) { _ in }
        }
    }
    
    
    func subscribe(to topic: String) {
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error {
                // CrashlyticsManager.record.error
                SecureLogger.error("Subscribe: \(topic), Error: \(error)")
            }
        }
    }
    
    func unsubscribe(from topic: String) {
        Messaging.messaging().unsubscribe(fromTopic: topic)
    }
    
    // ── UI helpers ───────────────────────────────────────
    func markAllRead() { unreadCount = 0 }
    func clearAll() {
        messages.removeAll()
        unreadCount = 0
    }
    
    private func uploadTokenToServer(_ token: String) {
        // API Call update the token to server
    }
}
