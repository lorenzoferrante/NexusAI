//
//  SignView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/2/25.
//

import SwiftUI
import AuthenticationServices
import Supabase

struct SignView: View {
    @State var supabaseClient = SupabaseManager.shared
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                userInfo()
                signUp()
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
    
    private func signUp() -> some View {
        SignInWithAppleButton { request in
            request.requestedScopes = [.email, .fullName]
        } onCompletion: { result in
            Task {
                await supabaseClient.logInTask(result)
            }
        }
        .signInWithAppleButtonStyle(.white)
        .cornerRadius(18)
        .frame(height: 50)
        .padding()
    }
    
    private func userInfo() -> some View {
        VStack(alignment: .leading) {
            Text("Authenticated: \(supabaseClient.isAuthenticated ? "Yes" : "No")")
            if supabaseClient.isAuthenticated {
                Text("\(supabaseClient.getUser()?.email ?? "No email")")
            }
        }
        .padding()
    }
    
}

#Preview {
    SignView()
//        .preferredColorScheme(.dark)
}
