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
    @State var provider = DefaultsManager.shared.getModel().provider
    @State var models: [OpenRouterModel] = []
    @State var selectedModel: OpenRouterModel = DefaultsManager.shared.getModel()
    
    @Binding var prompt: String
    
    @FocusState private var isFocused: Bool
    
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
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
        .onAppear {
            models = ModelsList.models.filter { $0.provider == provider }
            selectedModel = models.first(where: { $0.code == vm.selectedModel.code })!
        }
    }
    
    private var minimizedBar: some View {
        GlassEffectContainer {
            VStack(alignment: .leading) {
                HStack {
                    providerPicker
                    Spacer()
                    modelPicker
                }
                
                HStack {
                    Menu {
                        Button("Attach photos", action: {
                            feedbackGenerator.impactOccurred()
                            photosPickerIsPresented.toggle()
                        })
                        Button("Attach files", action: {
                            feedbackGenerator.impactOccurred()
                        })
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
                        feedbackGenerator.impactOccurred()
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .padding()
                    .disabled(prompt.isEmpty)
                }
            }
        }
    }
    
    private var maximizedBar: some View {
        GlassEffectContainer {
            VStack(alignment: .leading) {
                HStack {
                    providerPicker
                    Spacer()
                    modelPicker
                }
                
                TextField("Ask anything...", text: $prompt)
                    .lineLimit(5)
                    .padding()
                    .focused($isFocused)
                
                HStack {
                    Menu {
                        Button("Attach photos", action: {
                            feedbackGenerator.impactOccurred()
                            photosPickerIsPresented.toggle()
                        })
                        Button("Attach files", action: {
                            feedbackGenerator.impactOccurred()
                        })
                    } label: {
                        Image(systemName: "paperclip")
                    }
                    .tint(.secondary)
                    .menuStyle(.borderlessButton)
                    .padding([.leading])
                    
                    Button {
                        feedbackGenerator.impactOccurred()
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .padding()
                    .disabled(prompt.isEmpty)
                }
            }
        }
    }
    
    private var providerPicker: some View {
        Button {
            
        } label: {
            Text(provider.rawValue)
                .padding([.horizontal], 8)
                .padding([.vertical], 5)
                .background {
                    Capsule()
                        .fill(.thinMaterial)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1.0)
                }
                .padding()
                .tint(.primary.opacity(0.7))
        }
    }
    
    private var modelPicker: some View {
        Picker("Model", selection: $selectedModel) {
            ForEach(models, id: \.code) { model in
                Text(model.name)
                    .tag(model)
            }
        }
        .tint(.primary.opacity(0.7))
        .onChange(of: selectedModel) { _, newValue in
            DefaultsManager.shared.saveModel(newValue)
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
