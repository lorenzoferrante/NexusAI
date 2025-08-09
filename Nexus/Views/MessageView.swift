//
//  MessageView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import SwiftUI
import UIKit
import MarkdownUI

struct MessageView: View {
    let message: Message
    
    var body: some View {
        VStack {
            switch message.role {
            case .assistant:
                assistantMessage
            case .user:
                userMessage
            case .tool:
                toolMessage
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var userMessage: some View {
        VStack(alignment: .trailing) {
            if let imageURL = message.imageURL {
                HStack {
                    Spacer()
                    AsyncImage(url: URL(string: imageURL)!) { result in
                        result.image?
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(maxHeight: 100)
                    }
                }
            }
            Markdown(message.content ?? "")
                .markdownTheme(.defaultDark)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding()
    }
    
    private var assistantMessage: some View {
        Group {
            if let messageContent = message.content {
                VStack(alignment: .leading, spacing: 8) {
                    if !messageContent.isEmpty {
                        withAnimation {
                            HStack {
                                Image(systemName: "brain.fill")
                                    .foregroundColor(.secondary)
                                Text(OpenRouterAPI.shared.selectedModel.code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if !messageContent.isEmpty {
                        withAnimation {
                            Markdown(messageContent)
                                .markdownTheme(.defaultDark)
                                .textSelection(.enabled)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .opacity(1.0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            } else {
                Color.clear
            }
        }
    }
    
    // Changed from func to computed property and consolidated into one builder.
    private var toolMessage: some View {
        Group {
            if let toolName = message.toolName {
                let toolType = ToolsManager().getToolTypeFrom(toolName)
                let info = ToolsManager().getInfoFor(toolType) // [title, systemIconName].
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: info[1])
                            .foregroundColor(.secondary)
                        Text(info[0])
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    @Previewable @State var message: Message = .init(
        chatId: UUID(),
        role: .user,
        content: "Hello this is a user message with an image attached!",
        createdAt: Date()
    )
    
    @Previewable @State var toolMessage: Message = .init(
        chatId: UUID(),
        role: .tool,
        content: "",
        createdAt: Date()
    )
    
    @Previewable @State var assistantMessage: Message = .init(
        chatId: UUID(),
        role: .assistant,
        content: "Hello I am a simple AI assistant",
        createdAt: Date()
    )
    
    ZStack {
        BackView()
        VStack {
            MessageView(message: message)
                .padding()
                .preferredColorScheme(.dark)
            
            MessageView(message: toolMessage)
                .padding()
                .preferredColorScheme(.dark)
            
            MessageView(message: assistantMessage)
                .padding()
                .preferredColorScheme(.dark)
            
        }
        
    }
    .ignoresSafeArea()
    
}
