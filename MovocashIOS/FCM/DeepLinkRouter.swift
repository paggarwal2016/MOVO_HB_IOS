//
//  DeepLinkRouter.swift
//  MovocashIOS
//
//  Created by Movo Developer on 31/03/26.
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
        SecureLogger.debug("deep_link_push_\(type)")
    }
    
    func route(url: URL) {
        guard url.scheme?.lowercased() == "movocash" else { return }
        let host = url.host?.lowercased() ?? ""
        let id = url.pathComponents.first(where: { $0 != "/" })
        switch host {
        case "transaction":
            guard let id, !id.isEmpty else { return }
            destination = .transactionDetail(id: id)
        default:
            return
        }
        SecureLogger.debug("deep_link_url_\(host)")
    }
}
