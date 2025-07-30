//
//  BottomView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import SwiftUI

struct BottomBar: View {
    @State var vm = OpenRouterAPI.shared
    @State var isWebSearch: Bool = false
    @Binding var prompt: String
    
    @FocusState private var isFocused: Bool
    
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            
            GlassEffectContainer {
                VStack(alignment: .leading) {
                    TextField("Ask anything...", text: $prompt)
                        .lineLimit(5)
                        .padding()
                        .focused($isFocused)
                        .onSubmit {
                            generate()
                        }
                    
                    HStack {
                        Button {
                            feedbackGenerator.impactOccurred()
                            isWebSearch.toggle()
                        } label: {
                            Image(systemName: "network")
                        }
                        .tint(isWebSearch ? Color.accentColor : Color.secondary)
                        .padding()
                        
                        Spacer()
                        
                        Button {
                            generate()
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .padding()
                        .disabled(prompt.isEmpty)
                    }
                }
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .padding()
            }
        }
    }
    
    private func generate() {
        isFocused = false
        withAnimation {
            vm.chat.append(.init(role: .user, content: prompt))
            prompt = ""
        }
        
        Task {
            try await vm.stream(isWebSearch: isWebSearch)
        }
    }
}

#Preview {
    @Previewable @State var vm = OpenRouterAPI.shared
    @Previewable @State var prompt: String = ""
    BottomBar(prompt: $prompt)
}
