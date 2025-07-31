//
//  MessageView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import SwiftUI
import MarkdownUI

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
                        Markdown(message.content)
//                        Text(.init(message.content))
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
    let markdownTest = """
        # Title \
        ## Title 2 \
        This is a test view \
        > this is cited text \
        ```swift
        let hello = "World!"
        ```
        """
    @State var message: Message = .init(role: .assistant, content: markdownTest)
    MessageView(message: message)
}
