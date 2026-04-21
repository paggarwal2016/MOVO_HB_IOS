//
//  SignUpViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/04/26.
//

import Foundation
import Combine

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var email: String = ""

    var isValid: Bool { isValidEmail }

    var isValidEmail: Bool {
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}
