//
//  ProfileView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var lockManager: AppLockManager
    var body: some View {
        List {
            Section("Security") {
                NavigationLink {
                    SecuritySettingsView(lockManager: lockManager)
                } label: {
                    Label("Passcode & Biometrics", systemImage: "lock.shield")
                }
            }
        }
        .navigationTitle("Settings")
    }
}
