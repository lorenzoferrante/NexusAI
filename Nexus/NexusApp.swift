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
            if supabaseClient.isAuthenticated {
                NavigationSplitView {
                    SidebarView()
                } detail: {
                    ContentView()
                }
            } else {
                SignView()
            }
        }
    }
}
