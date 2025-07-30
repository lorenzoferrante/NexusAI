//
//  ContentView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import SwiftUI

struct ContentView: View {
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        
                    } label: {
                        Image(systemName: "list.dash")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reset()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Model", selection: $openRouterAPI.selectedModel) {
                        ForEach(Models.allCases, id: \.self) { model in
                            Text(model.rawValue)
                        }
                        .onChange(of: openRouterAPI.selectedModel) { _, newValue in
                            DefaultsManager.shared.saveModel(newValue)
                        }
                    }
                    .fixedSize()
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
            BottomBar(prompt: $prompt)
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
    ContentView()
        .onAppear {
            openRouterAPI.chat = [
                .init(role: .user, content: "Hello, who are you?"),
                .init(role: .assistant, content: answer),
            ]
        }
}
