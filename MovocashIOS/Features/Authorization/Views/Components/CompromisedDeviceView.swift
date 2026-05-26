//
//  CompromisedDeviceView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 24/02/26.
//

import SwiftUI

struct CompromisedDeviceView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.red)
            
            Text("Security Risk Detected")
                .font(.title2)
                .bold()
            
            Text("Your device appears to be jailbroken or rooted. For your safety, the app is disabled.")
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                // Optional: Retry check or exit app
            }) {
                Text("Retry Check")
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    CompromisedDeviceView()
}
