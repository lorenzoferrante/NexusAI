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
    
    @State var showModelSelection: Bool = false
    @State private var prompt: String = ""
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reset()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        RealtimeVoiceView()
                    } label: {
                        Image(systemName: "mic.circle")
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func reset() {
        withAnimation {
            openRouterAPI.chat.removeAll()
            prompt = ""
        }
    }
    
    private func bottomBar() -> some View {
        ZStack {
            BottomView(prompt: $prompt)
                .fixedSize(horizontal: false, vertical: true)
                .progressiveBlur()
        }
        .ignoresSafeArea()
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
