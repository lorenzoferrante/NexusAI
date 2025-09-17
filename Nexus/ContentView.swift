//
//  ContentView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import SwiftUI

struct ContentView: View {
    @State var supabaseManager = SupabaseManager.shared
    @State var openRouterAPI = OpenRouterAPI.shared
    
    @State private var prompt: String = ""
    @State private var showChatHistory = false
    @State private var chatCreationError: String?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackView()
                ChatView()
                    .safeAreaInset(edge: .bottom) {
                        bottomBar()
                    }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showChatHistory = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: startNewChat) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showChatHistory) {
                NavigationStack {
                    SidebarView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    showChatHistory = false
                                }
                            }
                        }
                }
            }
            .task {
                await ensureChatIsReady()
            }
            .onChange(of: supabaseManager.currentChat?.id) { _, _ in
                openRouterAPI.chat.removeAll()
                prompt = ""
            }
            .alert(
                "Unable to start chat",
                isPresented: Binding(
                    get: { chatCreationError != nil },
                    set: { newValue in
                        if !newValue {
                            chatCreationError = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    chatCreationError = nil
                }
            } message: {
                if let chatCreationError {
                    Text(chatCreationError)
                }
            }
//            .preferredColorScheme(.dark)
        }
    }
    
    private func startNewChat() {
        supabaseManager.beginDraftChat()
        openRouterAPI.chat.removeAll()
        prompt = ""
    }
    
    private func bottomBar() -> some View {
        ZStack {
            BottomView(prompt: $prompt)
                .fixedSize(horizontal: false, vertical: true)
                .progressiveBlur()
        }
        .ignoresSafeArea()
    }
    
    private func ensureChatIsReady() async {
        guard supabaseManager.isAuthenticated else { return }
        if let chatId = supabaseManager.currentChat?.id,
           supabaseManager.currentMessages.isEmpty {
            do {
                try await supabaseManager.retriveMessagesForChat(chatId)
            } catch {
                await MainActor.run {
                    chatCreationError = error.localizedDescription
                }
            }
        } else if supabaseManager.currentChat == nil {
            supabaseManager.beginDraftChat()
        }
    }
}

#Preview {
    @Previewable @State var openRouterAPI = OpenRouterAPI.shared
    let answer = """
        Hello! I'm an AI language model here to assist you with a variety of questions and topics. How can I help you today?
        """
    let chatID = UUID()
    ContentView()
        .onAppear {
            openRouterAPI.chat = [
                .init(chatId: chatID, role: .user, content: "Hello, who are you?", createdAt: Date()),
                .init(chatId: chatID, role: .assistant, content: answer, createdAt: Date()),
            ]
        }
}
