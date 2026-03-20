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
                ProfileImageView(imageURL: userImage,
                                 userName: userName,
                                 width: 50,
                                 height: 50)

                Spacer()
                
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
        .frame(height: 70)
    }
}
