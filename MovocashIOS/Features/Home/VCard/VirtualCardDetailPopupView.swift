//
//  VirtualCardDetailPopupView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import SwiftUI

struct VirtualCardDetailPopupView: View {
    
    let card: VCardsList
    @Binding var isPresented: Bool
    @State private var copiedField: String?
    
    var body: some View {
        BasePopupView(
            mode: .simple,
            isPresented: $isPresented
        ) {
            DetailField(
                label: "CARD NUMBER",
                value: card.cardNumber,
                copiedField: $copiedField,
                fullWidth: true,
                accentColor: Color.primary
            )
            
            Divider().padding(.horizontal, 20)
            
            HStack(alignment: .top, spacing: 0) {
                PlainField(label: "EXP DATE", value: card.expiration, fullWidth: true)
                Divider().frame(height: 60)
                PlainField(label: "CVC", value: card.cvc2, fullWidth: true)
            }
            
            Divider().padding(.horizontal, 20)
            
            PlainField(label: "NAME", value: card.name, fullWidth: true)
        }        
    }
}
