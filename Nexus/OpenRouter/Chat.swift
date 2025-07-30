//
//  Chat.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/30/25.
//

import SwiftData
import Foundation

@Model
@MainActor
class Chat {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var selectedModel: String
    
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.chat)
    var messages: [ChatMessage] = []
    
    init(title: String = "New Chat", selectedModel: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.selectedModel = selectedModel
    }
}