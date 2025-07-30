//
//  ChatDataManager.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/30/25.
//

import SwiftData
import SwiftUI

@MainActor
@Observable
class ChatDataManager {
    static let shared = ChatDataManager()
    private var modelContext: ModelContext?
    
    private init() {}
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // 1. Create new chat
    func createNewChat(title: String = "New Chat", selectedModel: String) -> Chat {
        let chat = Chat(title: title, selectedModel: selectedModel)
        guard let modelContext = modelContext else {
            fatalError()
        }
        
        modelContext.insert(chat)
        try? modelContext.save()
        return chat
    }
    
    // 2. Add message to chat
    func addMessage(to chat: Chat, role: MessageRole, content: String) {
        let message = ChatMessage(role: role, content: content)
        message.chat = chat
        chat.messages.append(message)
        chat.updatedAt = Date()
        
        // Auto-generate title from first user message
        if chat.title == "New Chat" && role == .user && !content.isEmpty {
            chat.title = String(content.prefix(50))
        }
        
        try? modelContext?.save()
    }
    
    // Update message content (useful for streaming)
    func updateMessage(_ message: ChatMessage, content: String) {
        message.content = content
        message.chat?.updatedAt = Date()
        try? modelContext?.save()
    }
    
    // 3. Delete chat
    func deleteChat(_ chat: Chat) {
        modelContext?.delete(chat)
        try? modelContext?.save()
    }
    
    // 4. Retrieve all chats
    func getAllChats() -> [Chat] {
        let descriptor = FetchDescriptor<Chat>(sortBy: [SortDescriptor(\Chat.updatedAt, order: .reverse)])
        return (try? modelContext?.fetch(descriptor)) ?? []
    }
    
    // Get most recent chat
    func getMostRecentChat() -> Chat? {
        var descriptor = FetchDescriptor<Chat>(sortBy: [SortDescriptor(\Chat.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? modelContext?.fetch(descriptor).first
    }
}
