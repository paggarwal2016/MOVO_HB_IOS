//
//  CardSkeletonView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation
import SwiftUI

struct CardSkeletonView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.heroCard)
            .fill(Color.movo.elevated)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.heroCard)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
            )
            .frame(height: 150)
            .shimmer()
    }
}
