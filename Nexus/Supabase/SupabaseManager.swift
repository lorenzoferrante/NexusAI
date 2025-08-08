//
//  SupabaseManager.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/2/25.
// Brilletta96_

import Foundation
import Supabase
import AuthenticationServices
import SwiftUI

@MainActor
@Observable
class SupabaseManager {
    
    static let shared = SupabaseManager()
    
    private let supabaseURLString = "https://mtsrrteuvxdzexlhcpoo.supabase.co"
    private let supabaseKey = ""
    let client: SupabaseClient
    
    public var isAuthenticated: Bool = false
    public var userHasProfile: Bool = false
    public var profile: Profile? = nil
    public var chats: [Chat] = []
    public var currentChat: Chat? = nil
    public var currentMessages: [Message] = []
    
    private init() {
        guard let supabaseURL = URL(string: supabaseURLString) else {
            fatalError()
        }
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        
        Task {
            for await state in client.auth.authStateChanges {
                if [.initialSession, .signedIn, .signedOut].contains(state.event) {
                    withAnimation {
                        isAuthenticated = state.session != nil
                    }
                }
            }
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
            
            await checkIfUserHasProfile()
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
        do {
            try await client
                .from("messages")
                .insert(message)
                .execute()
            debugPrint("[DEBUG] Added message to chat")
            
            await MainActor.run {
                debugPrint("[DEBUG] Appended message to currentMessages")
                self.currentMessages.append(message)
            }
            
        } catch {
            debugPrint("[DEBUG - addMessageToChat()] Error: \(error.localizedDescription)")
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
    
    public func updateLastMessage() {
        Task {
            let lastMessage = currentMessages.last(where: {$0.role == .assistant})!
            do {
                let message: Message = try await client
                    .from("messages")
                    .update(["content": lastMessage.content])
                    .eq("id", value: lastMessage.id)
                    .select()
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    debugPrint("[RESPONSE] \(message.content)")
                    self.currentMessages[self.currentMessages.count - 1].content = message.content
                }
                
                debugPrint("[DEBUG - updateLastMessage()] Updated last message")
            } catch {
                debugPrint("[DEBUG - updateLastMessage()] Error: \(error.localizedDescription)")
            }
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
}
