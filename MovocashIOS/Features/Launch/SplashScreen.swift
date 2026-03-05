//
//  SplashScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 04/03/26.
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                appState.flow = .choice
            }
        }
    }
}
