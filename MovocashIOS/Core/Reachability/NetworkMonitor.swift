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

    private let monitor: NWPathMonitor
    private var pendingWork: DispatchWorkItem?

    @Published var status: NetworkStatus = .connected

    private init() {
        // Simulator: NWPathMonitor() stays .satisfied while the Mac has any connectivity
        // (e.g. Ethernet), so turning off Mac WiFi alone never fires .disconnected.
        // Monitoring the WiFi interface specifically makes simulator testing accurate.
        // Device: full-path monitor — WiFi OR cellular = connected (correct for production).
        #if targetEnvironment(simulator)
        monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        #else
        monitor = NWPathMonitor()
        #endif

        // pathUpdateHandler fires on a background queue; all debounce work is
        // marshalled to the main queue so there are no threading issues.
        monitor.pathUpdateHandler = { [weak self] path in
            let newStatus: NetworkStatus = path.status == .satisfied ? .connected : .disconnected
            let delay: TimeInterval = newStatus == .disconnected ? 0 : 0.5

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingWork?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    self?.status = newStatus
                }
                self.pendingWork = work
                // Disconnection is immediate; reconnection is debounced 500 ms to
                // avoid banner flicker during cellular/wifi handoffs on real devices.
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    deinit { monitor.cancel() }
}
