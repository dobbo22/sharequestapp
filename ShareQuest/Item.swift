//
//  Item.swift
//  ShareQuest
//
//  Created by MartinD on 11/03/2026.
//

import Foundation

/// Item model that matches the API response
struct Item: Identifiable, Codable {
    let id: String
    var title: String
    var details: String?
    var isCompleted: Bool
    var priority: Int
    var timestamp: Date
    var ownerId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, details, isCompleted, priority, timestamp
        case ownerId = "owner_id"
    }
    
    init(id: String = UUID().uuidString, title: String, details: String? = nil, isCompleted: Bool = false, priority: Int = 0, timestamp: Date = Date(), ownerId: String? = nil) {
        self.id = id
        self.title = title
        self.details = details
        self.isCompleted = isCompleted
        self.priority = priority
        self.timestamp = timestamp
        self.ownerId = ownerId
    }
}

/// Request body for creating/updating items
struct ItemRequest: Codable {
    let title: String
    let details: String?
    let isCompleted: Bool?
    let priority: Int?
}
