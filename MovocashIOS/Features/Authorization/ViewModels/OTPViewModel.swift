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

    let maxLength: Int
    private var timerTask: Task<Void, Never>?

    var isValidOTP: Bool { otpText.count == maxLength }
    @Published private(set) var isSubmitting: Bool = false

    init(maxLength: Int = 6) {
        self.maxLength = maxLength
    }

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

        // Anchor to a fixed deadline so loop overhead never accumulates as drift
        let deadline = Date().addingTimeInterval(TimeInterval(seconds))

        timerTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let remaining = Int(deadline.timeIntervalSinceNow.rounded(.up))
                self.remainingSeconds = max(0, remaining)
                guard remaining > 0 else { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
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

    deinit {
        timerTask?.cancel()
    }
    
    // MARK: - Resend OTP
    func resetForResend() {
        otpText = ""
        startTimer()
    }

    // MARK: - Submit OTP
    func submitOTP(onVerify: @escaping @MainActor (String) async -> Void) async {
        guard isValidOTP, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        await onVerify(otpText)
    }
}
