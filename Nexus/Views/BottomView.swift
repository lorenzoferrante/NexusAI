//
//  BottomView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import SwiftUI
import PhotosUI

struct BottomBar: View {
    @State var vm = OpenRouterAPI.shared
    @State var isWebSearch: Bool = false
    @State var photosPickerIsPresented: Bool = false
    @Binding var prompt: String
    
    @FocusState private var isFocused: Bool
    
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            
            GlassEffectContainer {
                VStack(alignment: .leading) {
                    if let image = vm.selectedImage {
                        photoSection(Image(uiImage: image))
                    }
                    
                    TextField("Ask anything...", text: $prompt)
                        .lineLimit(5)
                        .padding()
                        .focused($isFocused)
                        .onSubmit {
                            generate()
                        }
                    
                    HStack(spacing: 0) {
                        Menu {
                            Button("Attach photos", action: { photosPickerIsPresented.toggle() })
                            Button("Attach files", action: { })
                        } label: {
                            Image(systemName: "plus")
                        }
                        .padding()
                        .tint(.secondary)
                        
                        Button {
                            feedbackGenerator.impactOccurred()
                            isWebSearch.toggle()
                        } label: {
                            Image(systemName: "network")
                        }
                        .tint(isWebSearch ? Color.accentColor : Color.secondary)
                        .buttonStyle(.bordered)
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
        .photosPicker(isPresented: $photosPickerIsPresented,
                      selection: $vm.photoPickerItems,
                      matching: .images)
    }
    
    private func photoSection(_ image: Image) -> some View {
        withAnimation {
            image
                .resizable()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10.0))
                .scaledToFill()
                .padding([.top, .leading, .trailing])
                .onLongPressGesture {
                    withAnimation {
                        vm.selectedImage = nil
                    }
                }
        }
    }
    
    private func generate() {
        isFocused = false
        let imageData = vm.base64FromSwiftUIImage()
        withAnimation {
            print("[DEBUG] Appending prompt: \(prompt)")
            vm.chat.append(.init(role: .user, content: prompt, imageData: imageData))
            prompt = ""
            vm.selectedImage = nil
        }
        
        Task {
            try await vm.stream(isWebSearch: isWebSearch)
        }
    }
    
    private func attachImage() {
        photosPickerIsPresented.toggle()
    }
}

#Preview {
    @Previewable @State var vm = OpenRouterAPI.shared
    @Previewable @State var prompt: String = ""
    BottomBar(prompt: $prompt)
        .preferredColorScheme(.dark)
}
