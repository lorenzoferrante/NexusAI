//
//  AssistantMessageView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 14/08/25.
//

import SwiftUI
import MarkdownUI

struct AssistantMessageView: View {
    let message: Message
    
    @State var orVM = OpenRouterViewModel.shared
    @State var isReasoningExpanded: Bool = false
    
    private let bottomID = "bottomID"
    
    var body: some View {
        VStack {
            assistantMessage
        }
        .frame(maxWidth: .infinity)
    }
    
    private var assistantMessage: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                withAnimation {
                    Group {
                        if (message.content != nil && !message.content!.isEmpty) || message.reasoning != nil {
                            HStack {
                                Image(systemName: "brain.fill")
                                    .foregroundColor(.secondary)
                                Text(
                                    message.modelName ??
                                    orVM.selectedModel.code
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            
                            if message.reasoning != nil {
                                reasoningView()
                            }
                            
                            if let content = message.content, !content.isEmpty {
                                Markdown(content)
                                    .markdownTheme(.defaultDark)
                                    .textSelection(.enabled)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .opacity(1.0)
                            }
                            
                            if let images = message.images {
                                HStack {
                                    ScrollView(.horizontal) {
                                        ForEach(images, id: \.self) { image in
                                            Image(base64DataString: image.imageURL.url)
                                        }
                                    }
                                }
                            }
                        } else {
                            thinkingAssistant()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.top, .bottom])
            .sheet(isPresented: $isReasoningExpanded) {
                NavigationStack {
                    ZStack {
                        reasoningBoxDetails()
                    }
                    .background(Material.ultraThinMaterial)
                    .toolbarTitleDisplayMode(.inlineLarge)
                    .navigationTitle("Reasoning")
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    private func reasoningView() -> some View {
        Group {
            VStack(alignment: .leading) {
                Button {
                    isReasoningExpanded.toggle()
                } label: {
                    HStack {
                        Markdown("Reasoning")
                            .markdownTheme(.defaultDark)
                            .bold()
                            .tint(.secondary)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .imageScale(.small)
                    }
                }
                .tint(.primary)
                
                reasoningBox()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 16.0))
    }
    
    private func reasoningBox() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Markdown(message.reasoning ?? "")
                        .markdownTheme(.secondaryDark)
                    Color.clear
                        .frame(height: .zero)
                        .id(bottomID)
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 50)
            .onChange(of: message.reasoning) { _, _ in
                proxy.scrollTo(bottomID)
            }
        }
    }
    
    private func reasoningBoxDetails() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Markdown(message.reasoning ?? "")
                        .markdownTheme(.secondaryDark)
                    Color.clear
                        .frame(height: .zero)
                        .id(bottomID)
                }
            }
            .padding()
            .scrollIndicators(.hidden)
            .onChange(of: message.reasoning) { _, _ in
                proxy.scrollTo(bottomID)
            }
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
                        Text(orVM.selectedModel.code)
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
    
    
}

#Preview {
    @Previewable @State var noReasoning: Message = .init(
        chatId: UUID(),
        role: .assistant,
        content: "We are asked if 15 is divisible by 3. Dividing 15 by 3 gives 5 with no remainder. Since there is no remainder, the answer is yes.",
        createdAt: Date()
    )
    
    @Previewable @State var reasoningShort: Message = .init(
        chatId: UUID(),
        role: .assistant,
        content: "Hello I am a simple AI assistant",
        reasoning: "We are asked if 15 is divisible by 3. Dividing 15 by 3 gives 5 with no remainder. Since there is no remainder, the answer is yes.",
        createdAt: Date()
    )
    
    @Previewable @State var reasoningMedium: Message = .init(
        chatId: UUID(),
        role: .assistant,
        content: "Hello I am a simple AI assistant",
        reasoning: "We are comparing the fuel efficiency of two cars: Car A gets 30 miles per gallon (mpg) and Car B gets 25 mpg. If both cars drive 300 miles, Car A will use 300 ÷ 30 = 10 gallons, while Car B will use 300 ÷ 25 = 12 gallons. Since 10 gallons is less than 12 gallons, Car A is more fuel-efficient.",
        createdAt: Date()
    )
    
    @Previewable @State var reasoningLong: Message = .init(
        chatId: UUID(),
        role: .assistant,
        content: "Hello I am a simple AI assistant",
        reasoning: "The riddle says: \"I am lighter than a feather, but even the strongest man can’t hold me for long. What am I?\" Let’s break it down: being “lighter than a feather” suggests something that has almost no weight. “Can’t hold me for long” suggests it’s intangible or fleeting. Common riddles with these clues often point to “breath” or “air” because you can’t hold your breath forever. Therefore, the answer is breath.",
        createdAt: Date()
    )
    
    ZStack {
        BackView()
        
        ScrollView {
            VStack(alignment: .leading) {
                AssistantMessageView(message: noReasoning)
                    .padding()
                    .preferredColorScheme(.dark)
                
                AssistantMessageView(message: reasoningShort)
                    .padding()
                    .preferredColorScheme(.dark)
                
                AssistantMessageView(message: reasoningMedium)
                    .padding()
                    .preferredColorScheme(.dark)
                
                AssistantMessageView(message: reasoningLong)
                    .padding()
                    .preferredColorScheme(.dark)
            }
        }
        
    }
    
}
