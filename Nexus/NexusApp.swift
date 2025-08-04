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
    
    var body: some Scene {
        WindowGroup {
            Group {
                if supabaseClient.isAuthenticated && supabaseClient.userHasProfile {
                    NavigationSplitView {
                        SidebarView()
                    } detail: {
                        ContentView()
                    }
                    .navigationSplitViewStyle(.prominentDetail)
                } else {
                    NavigationStack {
                        SignView()
                    }
                }
            }
            .onAppear {
                Task {
                    await supabaseClient.checkIfUserHasProfile()
                }
            }
        }
    }
}
