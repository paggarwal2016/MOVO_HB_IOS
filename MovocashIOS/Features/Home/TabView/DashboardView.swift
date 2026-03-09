//
//  DashboardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        VStack(spacing: 0) {

            UserHeaderView {
                Task {
                    await sessionManager.logout(appState: appState)
                }
            }

            Text("Home")
                .font(.largeTitle)
                .bold()
            Text("Welcome to the app!")
            Spacer()

        }
        .background(Color(.systemGroupedBackground))
    }
}
