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
    @Published var remainingSeconds: Int = 30
    @Published var state: OTPViewState = .idle

    let maxLength: Int = 6
    private var timerTask: Task<Void, Never>?

    var isValidOTP: Bool { otpText.count == maxLength }

    // MARK: - OTP Input
    func updateOTP(_ value: String) {
        let digits = value.filter { $0.isNumber }
        let truncated = String(digits.prefix(maxLength))
        otpText = truncated
    }

    // MARK: - Start Timer (iOS 15+ compatible)
    func startTimer(seconds: Int = 30) {
        stopTimer()
        remainingSeconds = seconds
        state = .counting

        timerTask = Task { [weak self] in
            guard let self else { return }

            while self.remainingSeconds > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second in nanoseconds
                self.remainingSeconds -= 1
            }

            if !Task.isCancelled {
                self.state = .expired
            }
        }
    }

    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
