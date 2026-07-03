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
    
    init(
        enabled: Bool = AppConfig.isSSLPinningEnabled,
        certificateName: String = AppConfig.pinnedCertificateName
    ) {
        self.pinningEnabled = enabled
        let hashes = enabled
        ? Self.loadPinnedKeyHashes(name: certificateName)
        : []
        
        if enabled && hashes.isEmpty {
            SecureLogger.error(
                "SSL pinning enabled but no bundled certificate public key could be loaded — all connections will be rejected. Ensure the pinned .cer files are added to the app target.",
                category: .security
            )
        }
        self.pinnedKeyHashes = hashes
        SecureLogger.info(
            "SSL pinning: enabled=\(enabled), pinned keys loaded=\(hashes.count)",
            category: .security
        )
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
        SecureLogger.info("SSL pinning: chain matched a pinned key — connection allowed", category: .security)
        return (.useCredential, URLCredential(trust: serverTrust))
    }
    
    /// Logs the rejection reason and returns the cancel disposition.
    private func reject(_ reason: String)
    -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        SecureLogger.error("\(reason) — rejecting connection", category: .security)
        return (.cancelAuthenticationChallenge, nil)
    }
    
    // MARK: - Key extraction
    private static func loadPinnedKeyHashes(name: String) -> Set<Data> {
        guard !name.isEmpty else {
            SecureLogger.error("No pinned certificate name configured for this environment", category: .security)
            return []
        }
        
        guard let url = Bundle.main.url(forResource: name, withExtension: "cer") else {
            SecureLogger.error("Pinned certificate '\(name).cer' not found in the app bundle", category: .security)
            return []
        }
        
        guard let data = try? Data(contentsOf: url),
              let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            SecureLogger.error("Failed to parse pinned certificate '\(url.lastPathComponent)'", category: .security)
            return []
        }
        
        guard let hash = publicKeyHash(from: certificate) else {
            SecureLogger.error("Failed to extract public key from pinned certificate '\(url.lastPathComponent)'", category: .security)
            return []
        }
        
        return [hash]
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
