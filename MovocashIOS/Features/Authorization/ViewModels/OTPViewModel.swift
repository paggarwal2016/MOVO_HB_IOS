//
//  OTPViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/02/26.
//

import Foundation
import Combine
import SwiftUI

enum OTPViewState {
    case idle
    case counting
    case expired
}

@MainActor
final class OTPViewModel: ObservableObject {

    @Published var otpText: String = ""
    @Published var remainingSeconds: Int = 10
    @Published var state: OTPViewState = .idle

    let maxLength: Int = 6
    private var timerTask: Task<Void, Never>?

    var isValidOTP: Bool { otpText.count == maxLength }

    // MARK: - OTP Input
    func updateOTP(_ value: String) {
        let digits = value.filter { $0.isNumber }
        let truncated = String(digits.prefix(maxLength))
        
        Task { @MainActor in
            otpText = truncated
        }
    }

    // MARK: - Modern Timer (Swift 6 Safe)
    func startTimer(seconds: Int = 10) {

        stopTimer()

        remainingSeconds = seconds
        state = .counting

        timerTask = Task {
            while remainingSeconds > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remainingSeconds -= 1
            }

            if !Task.isCancelled {
                state = .expired
            }
        }
    }

    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
