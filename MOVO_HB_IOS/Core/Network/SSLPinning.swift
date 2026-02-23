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

    init(enabled: Bool = true) {
        if enabled,
           let path = Bundle.main.path(forResource: "server", ofType: "cer") { // Server File
            pinnedCertData = try? Data(contentsOf: URL(fileURLWithPath: path))
        } else {
            pinnedCertData = nil
        }
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping
                    (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard let pinnedCertData else {
            completionHandler(.performDefaultHandling, nil)
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
