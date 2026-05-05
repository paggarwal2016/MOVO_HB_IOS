//
//  ContactRequest.swift
//  MovocashIOS
//
//  Created by Vinu on 05/05/26.
//

import Foundation

enum ContactRequest {
    
    struct AddFavourite: Codable, Equatable, Sendable {
        let contact_id: String
        let is_fav: Bool
        let addNewContact: Bool
        let userAction: String
    }
    
    struct DeleteFavourite: Codable, Equatable, Sendable {
        let favContacts: String
        let userAction: String
    }
    
    struct Create: Codable, Equatable, Sendable {
        let nickname: String
        let phoneNumber: String
        let is_fav: Bool
        let addNewContact: Bool
        let userAction: String
    }
    
    struct MarkFavourite: Codable, Equatable, Sendable {
        let is_fav: Bool
        let userAction: String
    }
    
    struct GetLists: Codable, Equatable, Sendable {
        let responseFlag: String
        let userAction: String
    }
    
}
