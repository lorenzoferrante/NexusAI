//
//  ErrorMessageView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/22/25.
//

import SwiftUI
import MarkdownUI

struct ErrorMessageView: View {
    let message: Message
    
    var body: some View {
        VStack {
            errorMessage
        }
        .frame(maxWidth: .infinity)
    }
    
    private var errorMessage: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                withAnimation {
                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.bubble.fill")
                                Text("Error")
                            }
                            .foregroundStyle(.red)
                            .fontWeight(.bold)
                            Markdown(message.content ?? "")
                                .markdownTheme(.defaultDark)
                                .textSelection(.enabled)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .opacity(1.0)
                            
                            Button {
                                Task {
                                    try await SupabaseManager.shared.cleanChatForRetry()
                                    try await OpenRouterViewModel.shared.stream()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.trianglehead.clockwise.rotate.90")
                                    Text("Retry")
                                }
                                .padding(.top)
                                .font(.footnote)
                                .tint(.secondary)
                            }
                        }
                        .padding([.leading, .trailing])
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.top, .bottom])
            .glassEffect(.regular.interactive().tint(.red.opacity(0.2)), in: .rect(cornerRadius: 16))
        }
    }
}

#Preview {
    @Previewable @State var errorMessage: Message = .init(
        chatId: UUID(),
        role: .error,
        content: "Reasoning is mandatory for this endpoint and cannot be disabled",
        createdAt: Date()
    )
    
    ZStack {
        BackView()
            .ignoresSafeArea()
        ErrorMessageView(message: errorMessage)
    }
    .preferredColorScheme(.dark)
    
}
