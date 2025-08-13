//
//  NexusApp.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import SwiftUI

@main
struct NexusApp: App {
    @State var supabaseClient = SupabaseManager.shared
    @State private var isCheckingProfile = true
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingProfile {
                    // Minimal splash while resolving auth/profile state
                    LoadingView()
                } else if supabaseClient.isAuthenticated && supabaseClient.userHasProfile {
                    NavigationSplitView {
                        SidebarView()
                    } detail: {
                        ContentView()
                    }
                    .navigationSplitViewStyle(.prominentDetail)
                } else if supabaseClient.isAuthenticated && !supabaseClient.userHasProfile {
                    CreateProfileView()
                } else {
                    NavigationStack {
                        SignView()
                    }
                }
            }
            .task(id: supabaseClient.isAuthenticated) {
                // Re-check profile whenever auth state changes
                if supabaseClient.isAuthenticated {
                    isCheckingProfile = true
                    await supabaseClient.checkIfUserHasProfile()
                    isCheckingProfile = false
                } else {
                    isCheckingProfile = false
                }
            }
            .task {
                _ = await CalendarManager.shared.requestAccess()
            }
            .preferredColorScheme(.dark)
        }
    }
}
