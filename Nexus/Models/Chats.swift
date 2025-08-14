//
//  Chats.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/4/25.
//

import Foundation

struct Chat: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var title: String?
    var model: String
    var systemPrompt: String?
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date? // nil = active (soft-delete flag)
    var totalTokens: Int?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userId       = "user_id"
        case title
        case model
        case systemPrompt = "system_prompt"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
        case deletedAt    = "deleted_at"
        case totalTokens  = "total_tokens"
    }
}

