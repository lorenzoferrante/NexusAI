//
//  RaycastBottomView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 31/07/25.
//

import SwiftUI

struct RaycastBottomView: View {
    @State var vm = OpenRouterAPI.shared
    @State var isWebSearch: Bool = false
    @State var photosPickerIsPresented: Bool = false
    
    @Binding var prompt: String
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            
            if isFocused {
                withAnimation {
                    maximizedBar
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                        .padding()
                }
            } else {
                withAnimation {
                    minimizedBar
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                        .padding()
                }
            }
        }
    }
    
    private var minimizedBar: some View {
        GlassEffectContainer {
            HStack {
                Menu {
                    Button("Attach photos", action: { photosPickerIsPresented.toggle() })
                    Button("Attach files", action: { })
                } label: {
                    Image(systemName: "paperclip")
                }
                .tint(.secondary)
                .menuStyle(.borderlessButton)
                .padding([.leading])
                
                TextField("Ask anything...", text: $prompt)
                    .lineLimit(1)
                    .padding()
                    .focused($isFocused)
                
                Button {
                    
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .padding()
//                .disabled(prompt.isEmpty)
            }
        }
    }
    
    private var maximizedBar: some View {
        GlassEffectContainer {
            TextField("Ask anything...", text: $prompt)
                .lineLimit(5)
                .padding()
                .focused($isFocused)
        }
    }
}

#Preview {
    @Previewable @State var vm = OpenRouterAPI.shared
    @Previewable @State var prompt: String = ""
    ZStack {
        BackView()
        RaycastBottomView(prompt: $prompt)
            .preferredColorScheme(.dark)
    }
}
