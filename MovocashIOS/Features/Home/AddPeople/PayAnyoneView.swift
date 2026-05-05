//
//  PayAnyoneView.swift
//  MovocashIOS
//
//  Created by Vinu on 05/05/26.
//

import Foundation
import SwiftUI
import Combine

struct PayAnyoneView: View {
    
    @State private var nickname = ""
    @State private var phone = ""
    
    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    addContactCard
                    orDivider
                    contactsCard
                }
                .padding()
            }
        }
    }
    
    var background: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(hex: "#0D1B2A"),
                Color.black
            ], startPoint: .top, endPoint: .bottom
        )
    }
    
    var headerSection: some View {
        VStack(spacing: 12) {
            
            Text("Pay Anyone")
                .font(AppFont.hero)
                .foregroundStyle(AppColor.white)
            
            Image("sendAnyone")
                .font(.system(size: 40))
                .foregroundStyle(.gray)
            
            Text("Send to anyone,\neven you nan")
                .font(AppFont.balance)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.white)
            
            Text("Add someone you pay often or pick from your contacts.")
                .font(AppFont.body)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    var addContactCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            Text("ADD NEW CONTACT")
                .font(AppFont.sectionHeader)
                .tracking(Tracking.value(0.08, size: 9))
                .foregroundStyle(.gray)
            
            TextField("Nickname (e.g., Mom, Roommate)", text: $nickname)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .foregroundColor(.white)
            
            HStack {
                Text("+1")
                    .foregroundStyle(.gray)
                
                Divider()
                    .frame(height: 20)
                    .background(.gray)
                
                TextField("(555) 000-0000", text: $phone)
                    .keyboardType(.numberPad)
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            // Buttons
            HStack {
                
                Button("Cancel") {}
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                
                Button("Add Contact") {}
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.7))
                    .foregroundColor(.black)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial)
        )
    }
    
    
    var orDivider: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
            
            Text("OR PICK FROM")
                .font(AppFont.sectionHeader)
                .foregroundColor(.gray)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
        }
    }
    
    var contactsCard: some View {
        VStack(spacing: 16) {
            
            Image(systemName: "person.3.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("Movo is better with friends")
                .font(AppFont.hero)
                .foregroundColor(.white)
            
            Text("Grant access to your contacts to find people on Movo and send money instantly.")
                .font(AppFont.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Enable Contacts") {
                // request permission
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green.opacity(0.7))
            .foregroundColor(.black)
            .cornerRadius(14)
            
            Button("How it works") {}
                .font(AppFont.body)
                .foregroundColor(.green)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial)
        )
    }
}


#Preview {
    PayAnyoneView()
}
