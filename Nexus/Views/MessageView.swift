//
//  MessageView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import SwiftUI

struct MessageView: View {
    @State var message: Message
    
    var body: some View {
        VStack {
            switch message.role {
            case .assistant:
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "brain.fill")
                        .foregroundColor(.secondary)
                    if message.content.isEmpty {
                        Text("Thinking...")
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                    } else {
                        Text(.init(message.content))
                            .textSelection(.enabled)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                    }
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16))
            case .user:
                Text(.init(message.content))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .trailing
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    @Previewable @State var message: Message = .init(role: .assistant, content: "Hello!")
    MessageView(message: message)
}
