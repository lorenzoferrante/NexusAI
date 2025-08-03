//
//  CreateProfileView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 03/08/25.
//

import SwiftUI
import Supabase

@MainActor
struct CreateProfileView: View {
    @State var supabaseManager = SupabaseManager.shared
    
    @State var username = ""
    @State var fullname = ""
    
    @State var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            BackView()
            
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Create your profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    GlassEffectContainer {
                        TextField("Username", text: $username)
                            .padding()
                            .glassEffect(.regular.interactive(), in: .capsule)
                        
                        TextField("Full Name", text: $fullname)
                            .padding()
                            .glassEffect(.regular.interactive(), in: .capsule)
                        
                        Button {
                            
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                    Text("Save profile")
                                }
                            }
                            .background(.clear)
                            .buttonStyle(.glassProminent)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .glassEffect(.regular.interactive(), in: .capsule)
                        }
                        
                    }
                }
                .padding()
            }
        }
    }
    
    func getInitialProfile() async {
        do {
            let currentUser = try await supabaseManager.client.auth.session.user
            let response = try await supabaseManager.client.from("profiles")
                .select()
                .eq("id", value: currentUser.id)
                .single()
                .execute()
            let profile: Profile = (response.value as? Profile)!
            
            username = profile.username ?? ""
            fullname = profile.fullname ?? ""
        } catch {
            debugPrint(error)
        }
    }
    
    func saveProfile() {
        Task {
            guard validateFields() else { return }
            isLoading = true
            defer { isLoading = false }
            
            do {
                let updatedProfile = Profile(username: username, fullname: fullname)
                let currentUser = try await supabaseManager.client.auth.session.user
                
                try await supabaseManager.client
                    .from("profiles")
                    .update(updatedProfile)
                    .eq("id", value: currentUser.id)
                    .execute()
            } catch {
                debugPrint(error)
            }
        }
    }
    
    func validateFields() -> Bool {
        if username
            .trimmingCharacters(in: .whitespaces)
            .isEmpty {
            return false
        }
        
        if username
            .trimmingCharacters(in: .whitespaces)
            .isEmpty {
            return false
        }
        
        return true
    }
}

#Preview {
    CreateProfileView()
}
