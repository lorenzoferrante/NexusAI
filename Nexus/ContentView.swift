//
//  ContentView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import SwiftUI

struct ContentView: View {
    @State var openRouterAPI = OpenRouterAPI.shared
    
    @State var showModelSelection: Bool = false
    @State private var prompt: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackView()
                
                ChatView()
                BottomBar(prompt: $prompt)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        
                    } label: {
                        Image(systemName: "list.dash")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reset()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Model", selection: $openRouterAPI.selectedModel) {
                        ForEach(Models.allCases, id: \.self) { model in
                            Text(model.rawValue)
                        }
                        .onChange(of: openRouterAPI.selectedModel) { _, newValue in
                            DefaultsManager.shared.saveModel(newValue)
                            reset()
                        }
                    }
                    .fixedSize()
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func reset() {
        withAnimation {
            openRouterAPI.chat.removeAll()
            prompt = ""
        }
    }
    
}
    
    #Preview {
        ContentView()
    }
