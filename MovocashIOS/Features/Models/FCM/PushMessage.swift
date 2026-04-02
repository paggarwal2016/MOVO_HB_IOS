//
//  PushMessage.swift
//  MovocashIOS
//
//  Created by Movo Developer on 31/03/26.
//

import Foundation

struct PushMessage: Identifiable {
    let id:         String
    let title:      String
    let body:       String
    let type:       PushType
    let amount:     String?
    let deepLink:   String?
    let receivedAt: Date

    enum PushType: String {
        case transaction = "transaction"
        case alert       = "alert"
        case promo       = "promo"
        case kyc         = "kyc"
        case general     = "general"

        var icon: String {
            switch self {
            case .transaction: return "arrow.left.arrow.right.circle.fill"
            case .alert:       return "exclamationmark.triangle.fill"
            case .promo:       return "tag.fill"
            case .kyc:         return "person.badge.clock.fill"
            case .general:     return "bell.fill"
            }
        }

        var color: String {
            switch self {
            case .transaction: return "blue"
            case .alert:       return "red"
            case .promo:       return "green"
            case .kyc:         return "orange"
            case .general:     return "gray"
            }
        }
    }

    init(userInfo: [AnyHashable: Any]) {
        let aps   = userInfo["aps"]   as? [String: Any]
        let alert = aps?["alert"]     as? [String: Any]
        id        = userInfo["gcm.message_id"] as? String ?? UUID().uuidString
        title     = alert?["title"]   as? String ?? userInfo["title"] as? String ?? "Notification"
        body      = alert?["body"]    as? String ?? userInfo["body"]  as? String ?? ""
        type      = PushType(rawValue: userInfo["type"] as? String ?? "") ?? .general
        amount    = userInfo["amount"]    as? String
        deepLink  = userInfo["deep_link"] as? String
        receivedAt = Date()
    }
}
