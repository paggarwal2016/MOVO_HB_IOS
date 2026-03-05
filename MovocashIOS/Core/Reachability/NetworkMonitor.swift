//
//  NetworkMonitor.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/03/26.
//

import Network
import Combine
import SwiftUI

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    @Published var status: NetworkStatus = .connected
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.status = path.status == .satisfied ? .connected : .disconnected
            }
        }
        monitor.start(queue: queue)
    }
}
