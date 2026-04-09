//
//  ACHRequest.swift
//  MovocashIOS
//
//  Created by Movo Developer on 09/04/26.
//

import Foundation

struct ACHRequest: Encodable, Sendable {
    let amount: String
    let achAccountId: String
}
