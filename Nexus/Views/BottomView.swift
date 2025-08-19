//
//  RaycastBottomView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 31/07/25.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Auth

struct BottomView: View {
    @State var supabaseManager = SupabaseManager.shared
    @State var vm = OpenRouterAPI.shared
    @State var isWebSearch: Bool = false
    
    @State var orVM = OpenRouterViewModel.shared
    
    @State var providers: Set<Providers> = []
    @State var provider = DefaultsManager.shared.getModel().provider
    @State var models: [OpenRouterModel] = []
    @State var selectedModel: OpenRouterModel = DefaultsManager.shared.getModel()
    
    @State var filePickerIsPresented: Bool = false
    @State var photosPickerIsPresented: Bool = false
    
    @Binding var prompt: String
    
    @FocusState private var isFocused: Bool
    
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            minimizedBar
        }
        .onAppear {
            providers = Set(ModelsList.models.map(\.provider))
            models = ModelsList.models.filter { $0.provider == provider }
            selectedModel = models.first(where: { $0.code == vm.selectedModel.code }) ?? DefaultsManager.shared.getModel()
        }
        .onChange(of: provider) { _, newValue in
            models = ModelsList.models.filter { $0.provider == newValue }
            selectedModel = models.first!
            DefaultsManager.shared.saveModel(selectedModel)
            vm.selectedModel = selectedModel
        }
        .onChange(of: selectedModel) { _, newValue in
            DefaultsManager.shared.saveModel(newValue)
            vm.selectedModel = selectedModel
        }
        .photosPicker(
            isPresented: $photosPickerIsPresented,
            selection: $vm.photoPickerItems,
            matching: .images
        )
        .fileImporter(
            isPresented: $filePickerIsPresented,
            allowedContentTypes: [.plainText, .pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                parseFile(urls)
            case .failure(let failure):
                print("[DEBUG] Erorr \(failure.localizedDescription)")
            }
        }
    }
    
    private var minimizedBar: some View {
        GlassEffectContainer {
            VStack {
                VStack(alignment: .leading) {
                    if let image = vm.selectedImage {
                        photoSection(Image(uiImage: image))
                    }
                    
                    if vm.selectedFileURL != nil {
                        fileSection()
                    }
                    
                    HStack {
                        providerPicker
                        Spacer()
                        modelPicker
                    }
                    
                    HStack(alignment: .center) {
                        Menu {                            
                            Button {
                                feedbackGenerator.impactOccurred()
                                photosPickerIsPresented.toggle()
                            } label: {
                                Label("Add photo", systemImage: "photo.fill")
                            }
                            
                            Button {
                                feedbackGenerator.impactOccurred()
                                filePickerIsPresented.toggle()
                            } label: {
                                Label("Add file", systemImage: "text.document")
                            }
                            
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
                            .onSubmit {
                                Task {
                                    await generate()
                                }
                            }
                        
                        Button {
                            feedbackGenerator.impactOccurred()
                            Task {
                                await generate()
                            }
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
    
    private var providerView: Label<Text, Image> {
        Label {
            Text(provider.rawValue)
        } icon: {
            Image(.google)
        }

    }
    
    private var providerPicker: some View {
        Menu {
            ForEach(Array(providers), id: \.rawValue) { provider in
                Button(provider.rawValue) {
                    self.provider = provider
                }
            }
        } label: {
            HStack {
                provider.icon()
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 20)
                Text(provider.rawValue)
            }
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
        .lineLimit(1)
        .tint(.primary.opacity(0.7))
        .padding(.trailing)
    }
    
    private func photoSection(_ image: Image) -> some View {
        HStack {
            withAnimation {
                image
                    .resizable()
                    .clipShape(RoundedRectangle(cornerRadius: 10.0))
                    .scaledToFit()
                    .frame(maxHeight: 80)
                    .padding([.top, .leading, .trailing])
                    .onLongPressGesture {
                        withAnimation {
                            vm.selectedImage = nil
                        }
                    }
            }
            Spacer()
        }
    }
    
    private func fileSection() -> some View {
        HStack {
            withAnimation {
                Image(systemName: "text.document")
                    .scaledToFit()
                    .frame(maxHeight: 80)
                    .padding([.top, .leading, .trailing])
                    .onLongPressGesture {
                        withAnimation {
                            vm.selectedImage = nil
                        }
                    }
            }
            Spacer()
        }
    }

    private func generate() async {
        isFocused = false
        
        if supabaseManager.currentMessages.count == 0 {
            await updateChatTitle()
        }

        let fileData = vm.fileContent()
        let fileName = vm.selectedFileURL?.lastPathComponent ?? nil
        let fileExtension = vm.selectedFileURL?.pathExtension.lowercased() ?? ""
        var pdfFileData: String?
        
        if fileExtension == "pdf" {
            pdfFileData = vm.base64FromFileURL()
        }
        
        var imageURL: String? = nil
        if let selectedImage = vm.selectedImage {
            let userID = supabaseManager.getUser()?.id.uuidString ?? "uploads"
            let fileName = "\(userID)/\(UUID().uuidString).jpeg"
            if let data = selectedImage.jpegData(compressionQuality: 0.5) {
                await supabaseManager.uploadImageToBucket(data, fileName: fileName)
                imageURL = supabaseManager.retrieveImageURLFor(fileName)
            }
        }

        withAnimation {
            print("[DEBUG] Appending prompt: \(prompt) to \(supabaseManager.currentChat!.id)")
            
            let newUserMessage: Message = .init(
                chatId: supabaseManager.currentChat!.id,
                role: .user,
                content: prompt,
                imageURL: imageURL,
                fileData: fileData,
                pdfData: pdfFileData,
                fileName: fileName,
                createdAt: Date()
            )
            
            Task {
                try await supabaseManager.addMessageToChat(newUserMessage)
                try await orVM.stream()
//                try await vm.stream()
                supabaseManager.updateLastMessage()
            }
            
            prompt = ""
            vm.selectedImage = nil
        }
    }
    
    private func attachImage() {
        photosPickerIsPresented.toggle()
    }
    
    private func parseFile(_ urls: [URL]) {
        if let url = urls.first {
            vm.selectedFileURL = url
        }
    }
    
    private func updateChatTitle() async {
        do {
            let chatTitle = try await vm.generateChatTitle(from: prompt) ?? "New chat"
            await supabaseManager.updateChatTitle(chatTitle)
        } catch {
            debugPrint("[DEBUG - generateChatTitle] Error: \(error)")
        }
    }
}

#Preview {
    @Previewable @State var vm = OpenRouterAPI.shared
    @Previewable @State var prompt: String = ""
    ZStack {
        BackView()
        BottomView(prompt: $prompt)
            .preferredColorScheme(.dark)
    }
}
