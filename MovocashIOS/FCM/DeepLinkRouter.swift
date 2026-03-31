//
//  DeepLinkRouter.swift
//  MovocashIOS
//
//  Created by Vinu on 31/03/26.
//

import Foundation
import Combine

@MainActor
class DeepLinkRouter: ObservableObject {
    
    static let shared = DeepLinkRouter()
    private init() {}

    @Published var destination: AppDestination?
    
    enum AppDestination: Hashable {
        case dashboard
        case transactions
        case transactionDetail(id: String)
        case transferMoney
        case cardManagement
        case kycVerification
        case notifications
        case settings
    }
    
    func routeFromPush(userInfo: [AnyHashable: Any]) {
        let type     = userInfo["type"]      as? String ?? ""
        let targetId = userInfo["target_id"] as? String ?? ""
        switch type {
        case "transaction": destination = targetId.isEmpty ? .transactions : .transactionDetail(id: targetId)
        case "transfer":    destination = .transferMoney
        case "card":        destination = .cardManagement
        case "kyc":         destination = .kycVerification
        default:            destination = .notifications
        }
        // AnalyticsManager.shared.logFeatureUsed(
        SecureLogger.debug("deep_link_push_\(type)")
    }
}
