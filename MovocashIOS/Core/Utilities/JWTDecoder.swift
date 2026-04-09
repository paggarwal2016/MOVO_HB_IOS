//
//  JWTDecoder.swift
//  MovocashIOS
//

import Foundation

enum JWTDecoder {

    /// Decodes the JWT payload segment into a dictionary.
    /// Does NOT verify the signature — server is responsible for that.
    /// Returns nil if the token is malformed or cannot be decoded.
    static func decodePayload(_ token: String) -> [String: Any]? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }

        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = base64.count % 4
        if rem > 0 { base64 += String(repeating: "=", count: 4 - rem) }

        guard
            let data = Data(base64Encoded: base64),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return json
    }
}
