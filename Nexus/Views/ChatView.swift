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
                    MessageView(message: message)
                        .padding([.trailing, .leading])
                }
                Color.clear
                    .frame(height: 1)
                    .id(bottomID)
            }
            .onChange(of: lastMessageContent) { _, _ in
                withAnimation {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .onAppear {
                if !supabaseManager.currentMessages.isEmpty {
                    withAnimation {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
            .onDisappear {
                if let chat = supabaseManager.currentChat, supabaseManager.currentMessages.isEmpty {
                    debugPrint("[DEBUG] Chat empty \(supabaseManager.currentChat!.id)")
                    supabaseManager.deleteChatWith(chat.id)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var openRouterAPI = OpenRouterAPI.shared
    ChatView()
        .onAppear {
            openRouterAPI.chat.append(contentsOf: [
                .init(chatId: UUID(), role: .user, content: "Hello!", createdAt: Date()),
                .init(chatId: UUID(), role: .assistant, content: "I am an LLM developed by DMP! How can I help you?", createdAt: Date())
            ])
        }
}
