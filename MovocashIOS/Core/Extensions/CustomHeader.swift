//
//  CustomHeader.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct CustomHeader: View {
    
    var title: String = ""
    var subtitle: String = ""
    var color: Color = .clear
    var showBack: Bool = true
    var onBack: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            
            HStack {
                if showBack {
                    Button {
                        onBack?()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.movo.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.movo.elevated)
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.movo.textPrimary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color.movo.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(color)
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }
}
