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
    
    @State var email = ""
    @State var username = ""
    @State var fullname = ""
    
    @State var isLoading: Bool = false
    
    @State var isEditing = false
    
    @State private var selectedCountry = ""
    let countries = [
        "United States",
        "Canada",
        "United Kingdom",
        "Germany",
        "France",
        "Italy",
        "Spain",
        "Australia",
        "India",
        "China",
        "Japan"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackView()
                
                ScrollView {
                    VStack(alignment: .leading) {
                        //                    Text("Welcome")
                        //                        .font(.largeTitle)
                        //                        .fontWeight(.bold)
                        
                        //                    Text("You are one step away from the power of AI in your pocket")
                        //                        .foregroundStyle(.secondary)
                        //                        .fontDesign(.monospaced)
                        //                        .padding([.bottom])
                        
                        CarouselView()
                            .frame(height: 120)
                        
                        GlassEffectContainer {
                            TextField("Email", text: $email)
                                .disabled(true)
                                .foregroundStyle(.secondary)
                                .padding()
                                .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 16))
                            
                            TextField("Username", text: $username)
                                .padding()
                                .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 16))
                            
                            TextField("Full Name", text: $fullname)
                                .padding()
                                .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 16))
                            
                            HStack(alignment: .lastTextBaseline) {
                                Text("Where are you from?")
                                    .padding([.leading])
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("Country", selection: $selectedCountry) {
                                    ForEach(countries, id: \.self) { country in
                                        Text(country)
                                            .tag(country)
                                    }
                                }
                            }
                            .padding([.top, .bottom])
                            
                            
                            Button {
                                saveProfile()
                            } label: {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                    } else {
                                        Text("Save profile")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .padding([.top, .bottom])
                                .frame(maxWidth: .infinity)
                            }
                            .tint(.black)
                            .background(
                                RoundedRectangle(cornerRadius: 16.0)
                                    .fill(.white)
                            )
                            .glassEffect(.clear.interactive())
                        }
                    }
                    .padding()
                }
                .onAppear {
                    Task {
                        await getInitialProfile()
                    }
                }
            }
            .navigationTitle("Your Profile")
//            .preferredColorScheme(.dark)
        }
    }
    
    func getInitialProfile() async {
        do {
            email = try await supabaseManager.client.auth.session.user.email ?? ""
            
            let currentUser = try await supabaseManager.client.auth.session.user
            let profile: Profile = try await supabaseManager.client.from("profiles")
                .select()
                .eq("id", value: currentUser.id)
                .single()
                .execute()
                .value
            supabaseManager.profile = profile
            username = profile.username ?? ""
            fullname = profile.fullname ?? ""
            selectedCountry = profile.country ?? countries.first!
        } catch {
            print("[DEBUG - getInitialProfile()] Error: \(error.localizedDescription)")
        }
    }
    
    func saveProfile() {
        Task {
            guard validateFields() else { return }
            isLoading = true
            defer { isLoading = false }
            
            do {
                let updatedProfile = Profile(
                    username: username,
                    fullname: fullname,
                    country: selectedCountry
                )
                let currentUser = try await supabaseManager.client.auth.session.user
                
                try await supabaseManager.client
                    .from("profiles")
                    .update(updatedProfile)
                    .eq("id", value: currentUser.id)
                    .execute()
                
                supabaseManager.isAuthenticated = true
                supabaseManager.userHasProfile = true
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
        
        if selectedCountry
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty {
            return false
        }
        
        return true
    }
}

#Preview {
    CreateProfileView()
}
