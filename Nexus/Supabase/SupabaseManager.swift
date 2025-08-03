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
    
}
