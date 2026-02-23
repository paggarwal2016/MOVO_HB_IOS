//
//  BlinkIDManager.swift
//  MovocashIOS
//
//  Created by Vinu on 23/02/26.
//

import Foundation
import Combine
import BlinkID
import BlinkIDUX
import MobileBankingKycSdk

@MainActor
final class BlinkIDManager: ObservableObject {

    // MARK: - Published Properties
    @Published var blinkIDUXModel: BlinkIDUXModel?
    @Published var scanningResult: BlinkIDScanningResult?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var sdk: BlinkIDSdk?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialize SDK
    func initialize() async {
        isLoading = true

        do {
            let settings = BlinkIDSdkSettings(
                licenseKey: "YOUR_LICENSE_KEY_HERE",
                downloadResources: true
            )

            sdk = try await BlinkIDSdk.createBlinkIDSdk(withSettings: settings)

            guard let sdk else { return }

            let analyzer = try await BlinkIDAnalyzer(
                sdk: sdk,
                eventStream: BlinkIDEventStream()
            )

            let model = BlinkIDUXModel(analyzer: analyzer)

            observeResult(model)

            blinkIDUXModel = model
            isLoading = false

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Observe Result
    private func observeResult(_ model: BlinkIDUXModel) {
        model.$result
            .compactMap { $0?.scanningResult }
            .sink { [weak self] result in
                self?.scanningResult = result
                print("Document Scanned Successfully")
            }
            .store(in: &cancellables)
    }

    // MARK: - Reset
    func reset() {
        scanningResult = nil
        blinkIDUXModel = nil
    }
}
