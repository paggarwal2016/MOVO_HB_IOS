//
//  SplashScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct SplashScreen: View {
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            Image("splash")
                .resizable()
                .scaledToFit()
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            appState.flow = .choice
        }
    }
}
