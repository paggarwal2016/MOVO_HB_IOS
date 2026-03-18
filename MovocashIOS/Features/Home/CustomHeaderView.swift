//
//  CustomHeaderView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import SwiftUI

struct CustomHeaderView: View {
    
    // MARK: - Properties
    
    var userName: String = "Test"
    var userImage: String = "profile"
    var onLogout: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.primary
                .ignoresSafeArea(edges: .top)
            
            HStack(spacing: 12) {
                
                // MARK: - User Image
                
                Image(userImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.cyan, lineWidth: 2.5)
                    )
                
                // MARK: - Greeting + Name
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Good day,")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    
                    Text(userName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                // MARK: - Bell Button
                
                Button {
                    // notifications
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.title3)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 44, height: 44)
                        .background(.white)
                        .clipShape(Circle())
                }
                
                // MARK: - Logout Button
                
                Button {
                    onLogout()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.title3)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 44, height: 44)
                        .background(.white)
                        .clipShape(Circle())
                }
            }
            .padding(.leading, 15)
            .padding(.trailing, 16)
            .padding(.bottom, 15)
        }
        .frame(height: 75)
    }
}
