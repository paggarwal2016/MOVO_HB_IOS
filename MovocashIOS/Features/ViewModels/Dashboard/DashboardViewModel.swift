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
        guard !Task.isCancelled else { return }
        dashboard = try? await network.request(DashboardAPI.dashboard)
    }
}
