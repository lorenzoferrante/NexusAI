//
//  ChatView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import SwiftUI

struct ChatView: View {
    @State var openRouterAPI = OpenRouterAPI.shared
    @State var supabaseManager = SupabaseManager.shared
    
    private var lastMessageContent: String {
        supabaseManager.currentMessages.last?.content ?? ""
    }
    
    private let bottomID = "bottomID"
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ForEach(supabaseManager.currentMessages, id: \.id) { message in
                    // Show tool messages regardless of content so we can display "Running..."
                    if message.role == .tool || message.content != nil {
                        MessageView(message: message)
                            .padding([.trailing, .leading])
                    }
                }
                
                if !supabaseManager.currentMessages.isEmpty {
                    chatStats()
                        .padding([.leading, .trailing])
                        .padding(.bottom, 0)
                        .id(bottomID)
                }
                    
            }
            .onChange(of: lastMessageContent) { _, _ in
                withAnimation {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .onAppear {
                Task {
                    try await supabaseManager.cleanChatOnOpen()
                }
                
                if !supabaseManager.currentMessages.isEmpty {
                    withAnimation {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
//            .onDisappear {
//                if let chat = supabaseManager.currentChat, supabaseManager.currentMessages.isEmpty {
//                    debugPrint("[DEBUG] Chat empty \(supabaseManager.currentChat!.id)")
//                    supabaseManager.deleteChatWith(chat.id)
//                }
//            }
        }
    }
    
    private func chatStats() -> some View {
        Group {
            if let currentChat = supabaseManager.currentChat {
                HStack {
                    Image(systemName: "text.word.spacing")
                    Text("Token count: ")
                    Text((currentChat.totalTokens ?? 0) as NSNumber, formatter: NumberFormatter.tokenCount)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    @Previewable @State var openRouterAPI = OpenRouterAPI.shared
    ZStack {
        BackView()
            
        ChatView()
            .onAppear {
                openRouterAPI.chat.append(contentsOf: [
                    .init(chatId: UUID(), role: .user, content: "Hello!", createdAt: Date()),
                    .init(chatId: UUID(), role: .assistant, content: "I am an LLM developed by DMP! How can I help you?", createdAt: Date())
                ])
            }
            .preferredColorScheme(.dark)
    }
}
