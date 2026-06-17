//
//  SSLPinning.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation
import Security
import CryptoKit

final class SecureSessionDelegate: NSObject, URLSessionDelegate {

    private let pinnedKeyHashes: Set<Data>
    private let pinningEnabled: Bool

    init(enabled: Bool = true) {
        self.pinningEnabled = enabled
        let hashes = enabled ? Self.loadPinnedKeyHashes() : []

        if enabled && hashes.isEmpty {
            SecureLogger.error(
                "SSL pinning enabled but no bundled certificate public key could be loaded — all connections will be rejected",
                category: .security
            )
        }
#if DEBUG
        SecureLogger.debug(
            "SSL pinning \(enabled ? "active with \(hashes.count) pinned key(s)" : "disabled")",
            category: .security
        )
#endif
        self.pinnedKeyHashes = hashes
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping
                    (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = evaluate(challenge)
        completionHandler(disposition, credential)
    }

    // MARK: - Challenge evaluation
    private func evaluate(_ challenge: URLAuthenticationChallenge)
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {

        guard pinningEnabled else {
            return (.performDefaultHandling, nil)
        }
        guard !pinnedKeyHashes.isEmpty else {
            return reject("SSL challenge received but no pinned keys are available")
        }
        // Only server-trust challenges are pinned. Any other challenge type
        // (client certificate, HTTP basic/digest, etc.) is handed back to the
        // default machinery — cancelling it here would break those auth flows.
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            return (.performDefaultHandling, nil)
        }
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            return reject("Server-trust challenge received without a serverTrust object")
        }
        guard SecTrustEvaluateWithError(serverTrust, nil) else {
            return reject("Server trust evaluation failed")
        }
        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              chain.contains(where: { Self.publicKeyHash(from: $0).map(pinnedKeyHashes.contains) ?? false }) else {
            return reject("No certificate in the server chain matched a pinned key")
        }
        return (.useCredential, URLCredential(trust: serverTrust))
    }

    /// Logs the rejection reason and returns the cancel disposition.
    private func reject(_ reason: String)
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        SecureLogger.error("\(reason) — rejecting connection", category: .security)
        return (.cancelAuthenticationChallenge, nil)
    }

    // MARK: - Key extraction
    private static func loadPinnedKeyHashes() -> Set<Data> {
        // Pin the public key of every bundled `.cer` (currently the Google Trust
        // Services "WR3" intermediate, `server.cer`). Enumerating all certificates
        // means a backup / rotation pin can be added simply by dropping another
        // `.cer` into the bundle — no code change required.
        let urls = Bundle.main.urls(forResourcesWithExtension: "cer", subdirectory: nil) ?? []

        return Set(urls.compactMap { url -> Data? in
            guard let data = try? Data(contentsOf: url),
                  let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
                return nil
            }
            return publicKeyHash(from: certificate)
        })
    }

    /// SHA-256 hash of a certificate's public key (external/DER representation).
    private static func publicKeyHash(from certificate: SecCertificate) -> Data? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let keyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        return Data(SHA256.hash(data: keyData))
    }
}
