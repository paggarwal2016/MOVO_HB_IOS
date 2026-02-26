//
//  SecureLogger.swift
//  MovocashIOS
//
//  Created by Movo Developer on 26/02/26.
//

import Foundation
import os

// MARK: - Log Levels

enum SecureLogLevel: String {
    case debug
    case info
    case warning
    case error
}

// MARK: - Secure Logger

final class SecureLogger {

    private static let subsystem = AppInfo.bundleIdentifier
    private static let logger = Logger(subsystem: subsystem, category: "SecureLog")

    private init() {}

    // Public logging entry
    static func log(
        _ message: @autoclosure () -> String,
        level: SecureLogLevel = .debug,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {

        #if DEBUG
        let sanitized = sanitize(message())
        let context = "[\(file):\(line)] \(function)"

        switch level {
        case .debug:
            logger.debug("\(sanitized, privacy: .public) \(context, privacy: .public)")
        case .info:
            logger.info("\(sanitized, privacy: .public)")
        case .warning:
            logger.warning("\(sanitized, privacy: .public)")
        case .error:
            logger.error("\(sanitized, privacy: .public)")
        }
        #endif
    }
}

private extension SecureLogger {

    static func sanitize(_ text: String) -> String {

        var value = text

        // JWT token
        value = value.replacingOccurrences(
            of: #"eyJ[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+"#,
            with: "[REDACTED_TOKEN]",
            options: .regularExpression
        )

        // Authorization header
        value = value.replacingOccurrences(
            of: "(?i)authorization:.*",
            with: "authorization:[REDACTED]",
            options: .regularExpression
        )

        // Long numeric sequences (account/card/otp)
        value = value.replacingOccurrences(
            of: #"\b\d{6,18}\b"#,
            with: "[REDACTED_NUMBER]",
            options: .regularExpression
        )

        // Email addresses
        value = value.replacingOccurrences(
            of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            with: "[REDACTED_EMAIL]",
            options: [.regularExpression, .caseInsensitive]
        )

        // JSON keys commonly sensitive
        let sensitiveKeys = [
            "token","access_token","refresh_token","otp","pin","password","mpin","card","cvv"
        ]

        for key in sensitiveKeys {
            value = value.replacingOccurrences(
                of: "\"\(key)\"\\s*:\\s*\".*?\"",
                with: "\"\(key)\":\"[REDACTED]\"",
                options: .regularExpression
            )
        }

        return value
    }
}
