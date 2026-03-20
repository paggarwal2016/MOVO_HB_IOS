//
//  ProfileImageView.swift
//  MovocashIOS
//
//  Created by Vinu on 20/03/26.
//

import Foundation
import SwiftUI

struct ProfileImageView: View {
    
    // MARK: - Properties
    let imageURL: String?
    let userName: String
    var width: CGFloat = 60
    var height: CGFloat = 60
    var borderColor: Color = .clear
    var borderWidth: CGFloat = 0
    var showOnline: Bool = false
    
    // MARK: - Initials
    var initials: String {
        let words = userName
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: " ")
        let letters = words.compactMap { $0.first }
        let result = String(letters.prefix(2)).uppercased()
        return result.isEmpty ? "?" : result
    }
    
    // MARK: - Font scales with size
    var fontSize: Font {
        let minSize = min(width, height)
        switch minSize {
        case 0..<30:   return .system(size: 10, weight: .bold)
        case 30..<40:  return .caption
        case 40..<60:  return .body
        case 60..<80:  return .title2
        case 80..<100: return .title
        default:       return .largeTitle
        }
    }
    
    // MARK: - Avatar color based on name
    var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .teal, .indigo, .cyan]
        let index = abs(userName.hashValue) % colors.count
        return colors[index]
    }
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            
            Group {
                if let urlString = imageURL,
                   let url = URL(string: urlString) {
                    
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                            
                        case .failure:
                            initialsView
                            
                        case .empty:
                            // Loading shimmer
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(ProgressView().tint(.white))
                            
                        @unknown default:
                            initialsView
                        }
                    }
                    
                } else {
                    initialsView
                }
            }
            .frame(width: width, height: height)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            
            // MARK: - Online indicator dot
            if showOnline {
                Circle()
                    .fill(Color.gray)
                    .frame(width: width * 0.22, height: height * 0.22)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 1.5)
                    )
                    .offset(x: 2, y: 2)
            }
        }
    }
    
    // MARK: - Initials fallback
    var initialsView: some View {
        Circle()
            .fill(.gray) // avatarColor
            .overlay(
                Text(initials)
                    .font(fontSize)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            )
    }
}
