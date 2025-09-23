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
                
                if supabaseManager.currentMessages.isEmpty {
                    emptyChatView()
                        .transition(.opacity)
                        .animation(.easeInOut, value: supabaseManager.currentMessages.isEmpty)

                }
                
                if !supabaseManager.currentMessages.isEmpty {
                    ForEach(supabaseManager.currentMessages, id: \.id) { message in
                        // Show tool messages regardless of content so we can display "Running..."
                        if message.role == .tool || message.content != nil {
                            MessageView(message: message)
                                .padding([.trailing, .leading])
                        }
                    }
                    
                    Color.clear
                        .frame(width: .infinity, height: 1.0)
                        .id(bottomID)
                    
//                    chatStats()
//                        .padding([.leading, .trailing])
//                        .padding(.bottom, 0)
//                        .id(bottomID)
                }
                    
            }
            .defaultScrollAnchor(
                supabaseManager.currentMessages.isEmpty ? .center : .top,
                for: .alignment
            )
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
    
    private func emptyChatView() -> some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Hello, \(getUserName())")
                .font(.system(size: 20, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
            Text("How can I help you today?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
        }
    }
    
    private func getUserName() -> String {
        guard let profile = supabaseManager.profile else {
            return ""
        }
        
        if let fullname = profile.fullname {
            return String(fullname.split(separator: " ").first ?? "")
        }
        
        return profile.username ?? ""
    }
}

#Preview {
    @Previewable @State var supabaseManager = SupabaseManager.shared
    @Previewable var messages = [
        Message(chatId: UUID(), role: .user, content: "Hello!", createdAt: Date()),
        Message(chatId: UUID(), role: .assistant, content: "I am an LLM developed by DMP! How can I help you?", createdAt: Date())
    ]
    @Previewable var user = Profile(username: "fernix96", fullname: "Lorenzo Ferrante", country: "Italy")
    
    ZStack {
//        BackView()
            
        ChatView()
            .onAppear {
//                supabaseManager.currentMessages.append(contentsOf: messages)
                supabaseManager.profile = user
            }
    }
}
