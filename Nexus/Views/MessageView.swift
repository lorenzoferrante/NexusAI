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
                AssistantMessageView(message: message)
            case .user:
                userMessage
            case .tool:
                toolMessage
            case .error:
                ErrorMessageView(message: message)
            default:
                EmptyView()
                    .frame(width: .zero)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var userMessage: some View {
        HStack {
            Spacer()
            
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
            //        .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
    }
    
    private var assistantMessage: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                withAnimation {
                    Group {
                        if !message.content!.isEmpty {
                            HStack {
                                Image(systemName: "brain.fill")
                                    .foregroundColor(.secondary)
                                Text(
                                    message.modelName ??
                                    OpenRouterAPI.shared.selectedModel.code
                                )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Markdown(message.content!)
                                .markdownTheme(.defaultDark)
                                .textSelection(.enabled)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .opacity(1.0)
                        } else {
                            thinkingAssistant()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.top, .bottom])
//            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
    }
    
    private func thinkingAssistant() -> some View {
        Group {
            if let lastMessage = SupabaseManager.shared.currentMessages.last,
               lastMessage.id == message.id {
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "brain.fill")
                            .foregroundColor(.secondary)
                        Text(OpenRouterAPI.shared.selectedModel.code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        ThinkingIndicatorView()
                        Markdown("Thinking...")
                            .markdownTheme(.defaultDark)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .opacity(1.0)
                    }
                }
            } else {
                EmptyView()
                    .frame(width: .zero)
                    .padding(0)
            }
        }
    }
    
    // Changed from func to computed property and consolidated into one builder.
    private var toolMessage: some View {
        Group {
            if let toolName = message.toolName {
                let toolType = ToolsManager.shared.getToolTypeFrom(toolName)
                let toolInfo = ToolsManager.shared.getInfoFor(toolType)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Using tool".uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Image(systemName: toolInfo.icon)
                            .foregroundColor(toolInfo.accentColor)
                        Text(toolInfo.name)
                            .foregroundStyle(.white)
                    }
                    
                    if let toolArgs = message.toolArgs {
                        Text(toolArgs)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
        toolName: "search_web",
        createdAt: Date()
    )
    
    @Previewable @State var emptyAssistant: Message = .init(
        chatId: UUID(),
        role: .assistant,
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
            
            MessageView(message: emptyAssistant)
                .padding()
                .preferredColorScheme(.dark)
            
            MessageView(message: assistantMessage)
                .padding()
                .preferredColorScheme(.dark)
            
        }
        
    }
    .ignoresSafeArea()
    
}
