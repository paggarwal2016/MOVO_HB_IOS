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
    
    @Published var pdfURL: URL?
    @Published var isLoading = false

    private let network: NetworkServiceProtocol
    private let analytics: AnalyticsTracking

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

        isLoading = true
        defer { isLoading = false }

        do {
            let response: DocumentResponse = try await perform {
                try await network.request(documentType.endpoint)
            }

            guard let url = response.documentURL else {
                throw NetworkError.invalidURL
            }

            self.pdfURL = url

        } catch {
            // handled in BaseViewModel
        }
    }
}
