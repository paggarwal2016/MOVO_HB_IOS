//
//  DashboardViewModel.swift
//  MovocashIOS
//
//  Created by Vinu on 14/04/26.
//

import Foundation
import Combine

@MainActor
final class DashboardViewModel: BaseViewModel {

    // MARK: - Published State

    @Published var dashboard: DashboardResponse?

    // MARK: - Dependencies

    private let network: NetworkServiceProtocol

    // MARK: - Init

    init(
        network: NetworkServiceProtocol,
        alertManager: AlertManagerProtocol
    ) {
        self.network = network
        super.init(alertManager: alertManager)
    }

    // MARK: - Fetch Dashboard

    func fetchDashboard() async {
        do {
            dashboard = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(DashboardAPI.dashboard)
            }
        } catch is CancellationError {
            // Task was cancelled — no action needed
        } catch {
            // error surfaced via BaseViewModel toast
        }
    }
}
