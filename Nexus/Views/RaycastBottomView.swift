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
            minimizedBar
        }
        .onAppear {
            models = ModelsList.models.filter { $0.provider == provider }
            selectedModel = models.first(where: { $0.code == vm.selectedModel.code })!
        }
    }
    
    private var minimizedBar: some View {
        GlassEffectContainer {
            VStack {
                VStack(alignment: .leading) {
                    HStack {
                        providerPicker
                        Spacer()
                        modelPicker
                    }
                    
                    HStack(alignment: .center) {
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
                        
                        TextField("Ask anything...", text: $prompt, axis: .vertical)
                            .lineLimit(5)
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
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
        .padding()
    }

    private var providerPicker: some View {
        Button {
            
        } label: {
            Text(provider.rawValue)
        }
        .buttonStyle(.bordered)
        .glassEffect(in: .capsule)
        .tint(.primary.opacity(0.7))
        .padding()
        
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
