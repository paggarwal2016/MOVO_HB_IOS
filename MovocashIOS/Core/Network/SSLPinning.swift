//
//  SSLPinning.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation
import Security

final class SecureSessionDelegate: NSObject, URLSessionDelegate {

    private let pinnedCertData: Data?
    private let pinningEnabled: Bool

    init(enabled: Bool = true) {
        self.pinningEnabled = enabled
        if enabled {
            if let path = Bundle.main.path(forResource: "server", ofType: "cer"),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                self.pinnedCertData = data
            } else {
                // Pinning is enabled but the certificate is missing from the bundle.
                // Log and hard-fail — never silently downgrade to default TLS.
                SecureLogger.error(
                    "SSL pinning enabled but server.cer is missing from the bundle — all connections will be rejected",
                    category: .security
                )
                self.pinnedCertData = nil
            }
        } else {
            self.pinnedCertData = nil
        }
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping
                    (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard pinningEnabled else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let pinnedCertData else {
            // Pinning is enabled but no cert loaded — hard fail, never downgrade.
            SecureLogger.error(
                "SSL challenge received but pinned cert is unavailable — rejecting connection",
                category: .security
            )
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let serverTrust = challenge.protectionSpace.serverTrust,
              let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let certificate = certificateChain.first else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let serverData = SecCertificateCopyData(certificate) as Data

        if serverData == pinnedCertData {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
