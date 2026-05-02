//
//  PDFViewModel.swift
//  MovocashIOS
//
//  Created by Vinu on 02/05/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class PDFViewModel: BaseViewModel {
    
    @Published var data: Data?
    
    // MARK: - Dependencies

    private let network: NetworkServiceProtocol
    private let analytics: AnalyticsTracking

    // MARK: - Init

    init(
        network: NetworkServiceProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking
    ) {
        self.network = network
        self.analytics = analytics
        super.init(alertManager: alertManager)
    }
    
    func loadPDF(for documentType: DocumentType) async {
        guard !Task.isCancelled else { return }
        do {
            data = try await perform {
                try await network.requestData(documentType.endpoint)
            }
        } catch {
            // Error surfaced via ToastManager in perform(_:)
        }
    }
}
