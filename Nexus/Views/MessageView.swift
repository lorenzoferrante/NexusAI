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
    @State var message: Message
    
    var body: some View {
        VStack {
            switch message.role {
            case .assistant:
                assistantMessage
            case .user:
                userMessage
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var userMessage: some View {
        VStack(alignment: .trailing) {
            if let imageData = message.imageData {
                HStack {
                    Spacer()
                    Image(base64DataString: imageData)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(maxHeight: 100)
                }
            }
            Markdown(message.content)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding()
    }
    
    private var assistantMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !message.content.isEmpty {
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
            if message.content.isEmpty {
                HStack {
                    ThinkingIndicatorView()
                    Markdown("Thinking...")
                }
            } else {
                Markdown(message.content)
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

#Preview {
    @Previewable @State var message: Message = .init(
        role: .user,
        content: "Hello this is a user message with an image attached!",
        imageData: "data:image/jpeg;base64,\(UIImage(resource: .test).pngData()!.base64EncodedString())")
    
    @Previewable @State var assistantMessage: Message = .init(
        role: .assistant,
        content: "Hello I am a simple AI assistant")
    
    ZStack {
        BackView()
        VStack {
            MessageView(message: message)
                .padding()
                .preferredColorScheme(.dark)
            
            MessageView(message: assistantMessage)
                .padding()
                .preferredColorScheme(.dark)
        }
        
    }
    .ignoresSafeArea()
    
}
