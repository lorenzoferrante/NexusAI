//
//  SupabaseManager.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/2/25.

import Foundation
import Supabase
import AuthenticationServices
import SwiftUI

@MainActor
@Observable
class SupabaseManager {
    
    static let shared = SupabaseManager()
    
    private let supabaseURLString = "https://mtsrrteuvxdzexlhcpoo.supabase.co"
    private let supabaseKey = "sb_publishable_q4F3wwoAbW9hQUa2p7T26A_zvEx-pVO"
    let client: SupabaseClient
    
    public var isAuthenticated: Bool = false {
        didSet {
            guard isAuthenticated != oldValue else { return }
            if isAuthenticated {
                Keychain.saveFlag(true, for: Keychain.AUTH_STATE_KEY)
            } else {
                Keychain.delete(Keychain.AUTH_STATE_KEY)
                Keychain.delete(Keychain.PROFILE_STATE_KEY)
            }
        }
    }
    public var userHasProfile: Bool = false {
        didSet {
            guard userHasProfile != oldValue else { return }
            if userHasProfile {
                Keychain.saveFlag(true, for: Keychain.PROFILE_STATE_KEY)
            } else {
                Keychain.delete(Keychain.PROFILE_STATE_KEY)
            }
        }
    }
    public var profile: Profile? = nil
    public var chats: [Chat] = []
    public var currentChat: Chat? = nil
    public var currentMessages: [Message] = []
    public var models: [OpenRouterModelRow] = []
    
    private init() {
        guard let supabaseURL = URL(string: supabaseURLString) else {
            fatalError()
        }
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        
        let cachedAuth = Keychain.loadFlag(Keychain.AUTH_STATE_KEY) ?? false
        let cachedProfile = Keychain.loadFlag(Keychain.PROFILE_STATE_KEY) ?? false
        let hasSession = client.auth.currentUser != nil
        isAuthenticated = hasSession || cachedAuth
        userHasProfile = (hasSession || cachedAuth) ? cachedProfile : false

        Task(priority: .background) { [weak self] in
            await self?.observeAuthChanges()
        }

        Task(priority: .background) { [weak self] in
            try? await self?.fetchAllModels()
        }

        if hasSession {
            Task(priority: .userInitiated) { [weak self] in
                await self?.refreshProfileState()
            }
        }
    }

    public func beginDraftChat() {
        currentChat = nil
        currentMessages = []
    }
    
    private func observeAuthChanges() async {
        for await state in client.auth.authStateChanges {
            guard [.initialSession, .signedIn, .signedOut].contains(state.event) else { continue }
            let signedIn = state.session != nil
            await MainActor.run {
                withAnimation {
                    self.isAuthenticated = signedIn
                }
            }
            if signedIn {
                await refreshProfileState()
            } else {
                await MainActor.run {
                    self.profile = nil
                    self.userHasProfile = false
                    self.chats = []
                    self.currentChat = nil
                    self.currentMessages = []
                }
            }
        }
    }

    private func refreshProfileState() async {
        await checkIfUserHasProfile()
        do {
            try await retriveChats()
            if currentChat == nil {
                beginDraftChat()
            }
        } catch {
            print("[DEBUG - refreshProfileState()] Error: \(error.localizedDescription)")
        }
    }
    
    public func logInTask(_ result: Result<ASAuthorization, any Error>) async {
        do {
            guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential else {
                return
            }
            
            guard let idToken = credential.identityToken
                .flatMap({ String(data: $0, encoding: .utf8) }) else {
                return
            }
            
            try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken
                )
            )
            
            await MainActor.run {
                isAuthenticated = true
            }
            
            await refreshProfileState()
        } catch {
            print("[DEBUG] SignUp Error: \(error.localizedDescription)")
        }
    }
    
    public func logOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("[DEBUG] SignOut Error: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isAuthenticated = false
            userHasProfile = false
        }
    }
    
    public func getUser() -> User? {
        if let currentUser = client.auth.currentUser {
            return currentUser
        } else {
            return nil
        }
    }
    
    public func checkIfUserHasProfile() async {
        do {
            let userID = try await client.auth.session.user.id
            let profile: Profile = try await client.from("profiles")
                .select()
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            print("[DEBUG - checkIfUserHasProfile()] Username: \(profile.username ?? "no username")")
            await MainActor.run {
                self.profile = profile
                userHasProfile = (profile.username != nil)
            }
        } catch {
            print("[DEBUG - checkIfUserHasProfile()] Error: \(error.localizedDescription)")
        }
    }
    
    public func createNewChat() async throws -> Chat {
        let chatId = UUID()
        let userId = try await client.auth.session.user.id
        let newChat = Chat(
            id: chatId,
            userId: userId,
            model: DefaultsManager.shared.getModel().code,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        try await client
            .from("chats")
            .insert(newChat)
            .execute()
        
        debugPrint("[DEBUG] Created new chat")
        
        await MainActor.run {
            self.currentChat = newChat
            self.chats.append(newChat)
        }
        
        try await retriveMessagesForChat(chatId)
        
        return newChat
    }
    
    public func retriveChats() async throws {
        let userId = try await client.auth.session.user.id
        let chats: [Chat] = try await client
            .from("chats")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        await MainActor.run {
            self.chats = chats
        }
        debugPrint("[DEBUG] Retrieved chats")
    }
    
    public func addMessageToChat(_ message: Message) async throws {
        await MainActor.run {
            debugPrint("[DEBUG] Appended message to currentMessages")
            self.currentMessages.append(message)
        }
        do {
            try await client
                .from("messages")
                .insert(message)
                .execute()
            debugPrint("[DEBUG] Added message to chat")
        } catch {
            debugPrint("[DEBUG - addMessageToChat()] Error: \(error.localizedDescription)")
        }
    }
    
    public func updateToolMessage(_ message: Message) async throws {
        // Update only the content of an existing tool message and reflect it locally by id.
        do {
            let updated: Message = try await client
                .from("messages")
                .update(["content": message.content ?? ""])
                .eq("id", value: message.id)
                .select()
                .single()
                .execute()
                .value

            await MainActor.run {
                if let index = self.currentMessages.firstIndex(where: { $0.id == message.id }) {
                    self.currentMessages[index].content = updated.content
                }
            }

            debugPrint("[DEBUG - updateToolMessage()] Updated tool message: \(message.id)")
        } catch {
            debugPrint("[DEBUG - updateToolMessage()] Error: \(error.localizedDescription)")
        }
    }
    
    public func retriveMessagesForChat(_ chatId: UUID) async throws {
        do {
            let messages: [Message] = try await client
                .from("messages")
                .select()
                .eq("chat_id", value: chatId)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            debugPrint("[DEBUG] Retrieved messaged for chat \(chatId)")
            
            DispatchQueue.main.async {
                self.currentMessages = messages
            }
        } catch {
            debugPrint("[DEBUG - retriveMessagesForChat()] Error: \(error.localizedDescription)")
        }
    }
    
    public func loadChatWith(_ chatID: UUID) async throws {
        do {
            let chat: Chat = try await client
                .from("chats")
                .select()
                .eq("id", value: chatID)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.currentChat = chat
            }
            
            try await retriveMessagesForChat(chatID)
        } catch {
            debugPrint("[DEBUG - loadChatWith()] Error: \(error.localizedDescription)")
        }
    }
    
    public func removeLastErrorMessage() {
        Task {
            let lastErrorMessages = currentMessages.filter { $0.role == .error }
            
            for lastErrorMessage in lastErrorMessages {
                do {
                    try await client
                        .from("messages")
                        .delete()
                        .eq("id", value: lastErrorMessage.id)
                        .select()
                        .single()
                        .execute()
                } catch {
                    debugPrint("[DEBUG - removeLastErrorMessage()] Error: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                self.currentMessages.removeAll(where: { lastErrorMessages.map(\.id).contains($0.id) })
            }
        }
    }
    
    public func cleanChatOnOpen() async throws {
        guard let lastMessage = currentMessages.last else {
            return
        }
        
        // Removes all error messages except if the last message of the chat was an error
        var errorMessages = currentMessages.filter { $0.role == .error }
        if errorMessages.last == lastMessage {
            errorMessages.removeLast()
        }
        for errorMessage in errorMessages {
            try await client
                .from("messages")
                .delete()
                .eq("id", value: errorMessage.id)
                .select()
                .execute()
        }
        
        // Removes all empty assistant messages
        let emptyMessages = currentMessages.filter { $0.content.isNilOrEmpty() && $0.role == .assistant }
        for emptyMessage in emptyMessages {
            try await client
                .from("messages")
                .delete()
                .eq("id", value: emptyMessage.id)
                .select()
                .execute()
        }
        
        await MainActor.run {
            self.currentMessages.removeAll(where: { emptyMessages.map(\.id).contains($0.id) })
        }
    }
    
    public func cleanChatForRetry() async throws {
        guard let currentChat = currentChat else {
            return
        }
        let chatId = currentChat.id
        
        if currentMessages.isEmpty {
            try await self.retriveMessagesForChat(chatId)
        }
    
        self.removeLastErrorMessage()
        
        let cleanedChat = self.currentMessages
            .filter {
                $0.role == .user ||
                ($0.role == .assistant && !$0.content.isNilOrEmpty())
            }
        self.currentMessages = cleanedChat
        
        try await client
            .from("messages")
            .delete()
            .eq("chat_id", value: chatId)
            .eq("role", value: "tool")
            .select()
            .execute()
        
        try await client
            .from("messages")
            .delete()
            .eq("chat_id", value: chatId)
            .eq("role", value: "assistant")
            .is("content", value: nil)
            .select()
            .execute()
        
        try await client
            .from("messages")
            .delete()
            .eq("chat_id", value: chatId)
            .eq("role", value: "assistant")
            .eq("content", value: "")
            .select()
            .execute()
        
        try await client
            .from("messages")
            .delete()
            .eq("chat_id", value: chatId)
            .eq("role", value: "error")
            .select()
            .execute()
    }
    
    public func updateLastMessage() {
        Task {
            guard let lastMessage = currentMessages.last(where: {$0.role == .assistant}) else {
                return
            }
            
            let currentModelCode = DefaultsManager.shared.getModel().code
            
            do {
                let message: Message = try await client
                    .from("messages")
                    .update([
                        "content": lastMessage.content,
                        "model_name": currentModelCode,
                    ])
                    .eq("id", value: lastMessage.id)
                    .select()
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    debugPrint("[RESPONSE] \(message.content ?? "")")
                    self.currentMessages[self.currentMessages.count - 1].content = message.content
                }
                
                debugPrint("[DEBUG - updateLastMessage()] Updated last message")
            } catch {
                debugPrint("[DEBUG - updateLastMessage()] Error: \(error.localizedDescription)")
            }
        }
    }
    
    public func updateMessageContent(withId messageId: UUID, content: String) {
        Task {
            do {
                let message: Message = try await client
                    .from("messages")
                    .update(["content": content])
                    .eq("id", value: messageId)
                    .select()
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    debugPrint("[RESPONSE] \(message.content ?? "")")
                    let index = self.currentMessages.firstIndex(where: { $0.id == messageId })!
                    self.currentMessages[index].content = message.content
                }
                
                debugPrint("[DEBUG - updateMessageContent()] Updated message")
            } catch {
                debugPrint("[DEBUG - updateMessageContent()] Error: \(error.localizedDescription)")
            }
        }
    }

    public func updateMessageToolCalls(messageId: UUID, toolCalls: [ToolCall]) async throws {
        struct UpdatePayload: Encodable {
            let toolCalls: [ToolCall]
            enum CodingKeys: String, CodingKey { case toolCalls = "tool_calls" }
        }
        do {
            // Persist tool_calls JSON for the given message
            let updated: Message = try await client
                .from("messages")
                .update(UpdatePayload(toolCalls: toolCalls))
                .eq("id", value: messageId)
                .select()
                .single()
                .execute()
                .value
            
            await MainActor.run {
                if let idx = self.currentMessages.firstIndex(where: { $0.id == messageId }) {
                    self.currentMessages[idx].toolCalls = updated.toolCalls
                }
            }
            debugPrint("[DEBUG - updateMessageToolCalls()] Updated tool_calls for message \(messageId)")
        } catch {
            debugPrint("[DEBUG - updateMessageToolCalls()] Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func uploadImageToBucket(_ data: Data, fileName: String) async {
        do {
            print("[DEBUG - uploadImageToBucket()] \(data.count)")
            
            try await client
                .storage
                .from("image-bucket")
                .upload(fileName, data: data, options: FileOptions(contentType: "image/jpeg"))
        } catch {
            debugPrint("[DEBUG - uploadImageToBucket()] Error: \(error)")
        }
    }
    
    public func retrieveImageURLFor(_ fileName: String) -> String {
        do {
            let imageURL = try client
                .storage
                .from("image-bucket")
                .getPublicURL(path: fileName)
            
            debugPrint("[DEBUG - retrieveImageURLFor()] URL: \(imageURL.absoluteString)")
            return imageURL.absoluteString
        } catch {
            debugPrint("[DEBUG - retrieveImageURLFor()] Error: \(error)")
            return ""
        }
    }
    
    public func uploadFileToBucket(_ content: String, fileName: String) async {
        do {
            print("[DEBUG - uploadFileToBucket()] \(fileName)")
            
            try await client
                .storage
                .from("doc-bucket")
                .upload(fileName, data: content.data(using: .utf8)!, options: FileOptions.init(contentType: "text/plain"))
        } catch {
            debugPrint("[DEBUG - uploadImageToBucket()] Error: \(error)")
        }
    }
    
    public func retrieveFileURLFrom(_ fileName: String) -> String {
        do {
            let fileURL = try client
                .storage
                .from("doc-bucket")
                .getPublicURL(path: fileName)
            
            debugPrint("[DEBUG - retrieveFileFrom()] URL: \(fileURL)")
            return fileURL.absoluteString
        } catch {
            debugPrint("[DEBUG - retrieveImageURLFor()] Error: \(error)")
            return ""
        }
    }
    
    public func updateChatTitle(_ title: String) async {
        do {
            try await client
                .from("chats")
                .update(["title": title])
                .eq("id", value: currentChat!.id)
                .execute()
            
            await MainActor.run {
                currentChat!.title = title
            }
        } catch {
            debugPrint("[DEBUG - updateChatTitle()] Error: \(error)")
        }
    }
    
    public func deleteChat(at offset: Int) {
        let chatId = self.chats[offset].id
        self.chats.remove(at: offset)
        
        Task {
            do {
                try await client.from("messages")
                    .delete()
                    .eq("chat_id", value: chatId)
                    .execute()
                
                debugPrint("[DEBUG] Deleted messages for chat \(chatId)")
                
                try await client.from("chats")
                    .delete()
                    .eq("id", value: chatId)
                    .execute()
                
                debugPrint("[DEBUG] Deleted chat \(chatId)")
            } catch {
                debugPrint("[DEBUG - deleteChat] Error: \(error.localizedDescription)")
            }
        }
    }
    
    public func deleteChatWith(_ chatId: UUID) {
        self.chats.removeAll(where: { $0.id == chatId })
        
        Task {
            do {
                try await client.from("messages")
                    .delete()
                    .eq("chat_id", value: chatId)
                    .execute()
                
                debugPrint("[DEBUG] Deleted messages for chat \(chatId)")
                
                try await client.from("chats")
                    .delete()
                    .eq("id", value: chatId)
                    .execute()
                
                debugPrint("[DEBUG] Deleted chat \(chatId)")
            } catch {
                debugPrint("[DEBUG - deleteChat] Error: \(error.localizedDescription)")
            }
        }
    }
    
    public func ensureOpenRouterKey() async throws -> String {
        struct KeyResponse: Decodable {
            let key: String
        }
        
        if let cached = Keychain.load(Keychain.OPENROUTER_USER_KEY) { return cached }
        let response: KeyResponse = try await client.functions
            .invoke(
                "openrouter-issue-key",
                options: FunctionInvokeOptions(
                    body: ["forceRotate": false]
                )
            )
        let key = response.key
        Keychain.save(key, for: Keychain.OPENROUTER_USER_KEY)
        return key
    }
    
    @discardableResult
    public func search(
        query: String,
        numResults: Int = 5,
        type: String = "keyword",
        includeText: Bool = true,
        includeContext: Bool = true
    ) async throws -> [ExaResult] {
        let payload: [String: Any] = [
            "query": query,
            "type": type,
            "numResults": numResults,
            "contents": ["text": includeText, "context": includeContext]
        ]
        
        let result: ExaResultsEnvelope = try await client.functions
            .invoke(
                "exa-search",
                options: FunctionInvokeOptions(
                    body: try JSONSerialization.data(withJSONObject: payload)
                )
            )
        return result.results
    }
    
    @discardableResult
    public func crawl(
        ids: [String],
        includeText: Bool = true
    ) async throws -> [ExaResult] {
        let payload: [String: Any] = [
            "ids": ids,
            "text": includeText
        ]
        
        let result: ExaResultsEnvelope = try await client.functions
            .invoke(
                "exa-crawl",
                options: FunctionInvokeOptions(
                    body: try JSONSerialization.data(withJSONObject: payload)
                )
            )
        return result.results
    }
    
    public func fetchAllModels() async throws {
        let rows: [OpenRouterModelRow] = try await client
            .from("openrouter_models")
            .select()
            .execute()
            .value
        debugPrint("[DEBUG] fetchAllModels - fetched \(rows.count) models.")
        await MainActor.run {
            self.models = rows
            DefaultsManager.shared.reconcileModelSelection(with: rows)
        }
    }

    /// Optional: fetch by provider
    public func fetchModelBy(provider: Providers) async throws -> [OpenRouterModelRow] {
        let rows: [OpenRouterModelRow] = try await client
            .from("openrouter_models")
            .select()
            .eq("provider", value: provider.rawValue)
            .order("name", ascending: true)
            .execute()
            .value
        return rows
    }
}
