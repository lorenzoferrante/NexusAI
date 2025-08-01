//
//  ChatView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import SwiftUI

struct ChatView: View {
    @State var openRouteAPI = OpenRouterAPI.shared
    
    private var lastMessageContent: String {
        openRouteAPI.chat.last?.content ?? ""
    }
    
    private let bottomID = "bottomID"
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ForEach(openRouteAPI.chat, id: \.content) { message in
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
        }
    }
}

#Preview {
    @Previewable @State var openRouteAPI = OpenRouterAPI.shared
    ChatView()
        .onAppear {
            openRouteAPI.chat.append(contentsOf: [
                .init(role: .user, content: "Hello!"),
                .init(role: .assistant, content: "I am an LLM developed by DMP! How can I help you?")
            ])
        }
}
