//
//  SupabaseManager.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/2/25.
//

import Foundation
import Supabase
import AuthenticationServices

@MainActor
@Observable
class SupabaseManager {
    
    static let shared = SupabaseManager()
    
    private let supabaseURLString = "https://mtsrrteuvxdzexlhcpoo.supabase.co"
    private let supabaseKey = ""
    let client: SupabaseClient
    
    public var isAuthenticated: Bool {
        return client.auth.currentUser != nil
    }
    
    private init() {
        guard let supabaseURL = URL(string: supabaseURLString) else {
            fatalError()
        }
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
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
    }
    
    public func getUser() -> User? {
        if let currentUser = client.auth.currentUser {
            return currentUser
        } else {
            return nil
        }
    }
    
}
