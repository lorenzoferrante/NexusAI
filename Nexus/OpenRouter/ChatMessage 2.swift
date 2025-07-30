//
//  ChatMessage.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/30/25.
//

import SwiftData
import Foundation

@Model
@MainActor
class ChatMessage {
    @Attribute(.unique) var id: UUID
    var role: String
    var content: String
    var timestamp: Date
    
    @Relationship var chat: Chat?
    
    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.role = role.rawValue
        self.content = content
        self.timestamp = Date()
    }
}

enum MessageRole: String, CaseIterable {
    case user = "user"
    case assistant = "assistant"
}