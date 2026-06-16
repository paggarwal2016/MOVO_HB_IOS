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
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            return reject("Challenge is not a server-trust challenge")
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
        var urls: [URL] = []
        if let server = Bundle.main.url(forResource: "server", withExtension: "cer") {
            urls.append(server)
        }
        urls.append(contentsOf: Bundle.main.urls(forResourcesWithExtension: "cer", subdirectory: nil) ?? [])

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
