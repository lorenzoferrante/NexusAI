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
    @State var defaultsManager = DefaultsManager.shared
    @State var supabaseManager = SupabaseManager.shared
    @State var vm = OpenRouterAPI.shared
    @State var isWebSearch: Bool = false
    
    @State var orVM = OpenRouterViewModel.shared
    
    @State var providers: Set<Providers> = []
    @State var provider = DefaultsManager.shared.getModel().toProvider()
    @State var models: [OpenRouterModelRow] = []
    @State var selectedModel: OpenRouterModelRow = DefaultsManager.shared.getModel()
    
    @State var filePickerIsPresented: Bool = false
    @State var photosPickerIsPresented: Bool = false
    
    @Binding var prompt: String
    
    @FocusState var isFocused: Bool
    
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            minimizedBar
        }
        .onAppear {
            isFocused = true
            providers = Set(supabaseManager.models.map { $0.toProvider() })
            models = supabaseManager.models.filter { $0.provider == provider.rawValue }
            selectedModel = models.first(where: { $0.code == orVM.selectedModel.code }) ?? DefaultsManager.shared.getModel()
        }
        .onChange(of: provider) { _, newValue in
            models = supabaseManager.models.filter { $0.provider == newValue.rawValue }
            if let firstMatch = models.first {
                selectedModel = firstMatch
            } else {
                let fallback = DefaultsManager.shared.getModel()
                selectedModel = fallback
                models = [fallback]
            }
            DefaultsManager.shared.saveModel(selectedModel)
            orVM.selectedModel = selectedModel
        }
        .onChange(of: selectedModel) { _, newValue in
            DefaultsManager.shared.saveModel(newValue)
            orVM.selectedModel = selectedModel
        }
        .onChange(of: supabaseManager.models) { _, newValue in
            providers = Set(newValue.map { $0.toProvider() })
            models = newValue.filter { $0.provider == provider.rawValue }
            if let saved = newValue.first(where: { $0.code == DefaultsManager.shared.getModel().code }) {
                selectedModel = saved
            }
        }
        .photosPicker(
            isPresented: $photosPickerIsPresented,
            selection: $vm.photoPickerItem,
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
                            Image(systemName: orVM.isStreaming ? "stop.fill" : "paperplane.fill")
                        }
                        .padding()
                        .disabled(prompt.isEmpty)
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        ThemeColors
                            .from(color: defaultsManager.selectedThemeColor)
                            .opacity(0.2),
                        ThemeColors
                            .from(color: defaultsManager.selectedThemeColor)
                            .opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: .rect(cornerRadius: 18)
            )
            
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
        .glassEffect(.regular.interactive(), in: .capsule)
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
            image
                .resizable()
                .clipShape(RoundedRectangle(cornerRadius: 10.0))
                .scaledToFit()
                .frame(maxHeight: 80)
                .padding([.top, .leading, .trailing])
                .onLongPressGesture {
                    withAnimation {
                        vm.selectedImage = nil
                        vm.photoPickerItem = nil
                    }
                }
            Spacer()
        }
    }
    
    private func fileSection() -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "doc.richtext")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 44)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.selectedFileURL?.lastPathComponent ?? "PDF")
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("Long-press to remove")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding([.top, .horizontal])
        .onLongPressGesture {
            withAnimation {
                vm.selectedFileURL = nil
            }
        }
    }

    private func generate() async {
        isFocused = false
        let originalPrompt = prompt
        let trimmedPrompt = originalPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        do {
            let chat: Chat
            if let existingChat = supabaseManager.currentChat {
                chat = existingChat
            } else {
                chat = try await supabaseManager.createNewChat()
            }

            if supabaseManager.currentMessages.isEmpty {
                await updateChatTitle(using: trimmedPrompt)
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
                let remoteFileName = "\(userID)/\(UUID().uuidString).jpeg"
                if let data = selectedImage.jpegData(compressionQuality: 0.6) {
                    await supabaseManager.uploadImageToBucket(data, fileName: remoteFileName)
                    let remoteURL = supabaseManager.retrieveImageURLFor(remoteFileName)
                    if !remoteURL.isEmpty {
                        imageURL = remoteURL
                    }
                }
            }

            let newUserMessage = Message(
                chatId: chat.id,
                role: .user,
                content: originalPrompt,
                imageURL: imageURL,
                fileData: fileData,
                pdfData: pdfFileData,
                fileName: fileName,
                createdAt: Date()
            )

            try await supabaseManager.addMessageToChat(newUserMessage)

            await MainActor.run {
                prompt = ""
                vm.selectedImage = nil
                vm.photoPickerItem = nil
                vm.selectedFileURL = nil
            }

            try await orVM.stream()
            supabaseManager.updateLastMessage()
        } catch {
            debugPrint("[DEBUG - BottomView.generate] Error: \(error.localizedDescription)")
        }
    }
    
    private func attachImage() {
        photosPickerIsPresented.toggle()
    }
    
    private func parseFile(_ urls: [URL]) {
        if let url = urls.first {
            withAnimation {
                vm.selectedImage = nil
                vm.selectedFileURL = url
            }
            vm.photoPickerItem = nil
        }
    }
    
    private func updateChatTitle(using prompt: String) async {
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
//            .preferredColorScheme(.dark)
    }
}
