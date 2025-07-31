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
                VStack(alignment: .trailing) {
                    if let imageData = message.imageData,
                    let image = imageFromBase64(imageData) {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200)
                    }
                    Text(.init(message.content))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .trailing
                        )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    func imageFromBase64(_ base64String: String) -> Image? {
        // Remove metadata if present
        let cleanString: String
        if let commaIndex = base64String.firstIndex(of: ",") {
            cleanString = String(base64String[base64String.index(after: commaIndex)...])
        } else {
            cleanString = base64String
        }
        
        // Decode base64 to Data
        guard let imageData = Data(base64Encoded: cleanString) else { return nil }
        
        // Create UIImage and then SwiftUI Image
        guard let uiImage = UIImage(data: imageData) else { return nil }
        return Image(uiImage: uiImage)
    }
}

#Preview {
    let markdownTest = """
        # Main title
        ## Title 2
        ### Title 3
        This is a test view
        > this is cited text
        ```swift
        let hello = "World!
        ```
        """
    let userMessageTest = "Hello this a user message"
    let image = UIImage(resource: .test).pngData()
    @State var message: Message = .init(role: .user, content: userMessageTest, imageData: "data:image/jpeg;base64,\(image)")
    ZStack {
        BackView()
        MessageView(message: message)
            .padding()
            .preferredColorScheme(.dark)
    }
    .ignoresSafeArea()
    
}
