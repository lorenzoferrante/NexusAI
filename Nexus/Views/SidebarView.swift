//
//  SidebarView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 02/08/25.
//

import SwiftUI
import Supabase

struct SidebarView: View {
    @State private var supabaseClient = SupabaseManager.shared
    
    var body: some View {
        ZStack {
            BackView()
                .ignoresSafeArea()
            
            VStack {
                chatList
                Spacer()
                bottomBar
            }
        }
        .navigationTitle("NexusAI")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    ContentView()
                } label: {
                    Label("", systemImage: "plus")
                        .glassEffect(in: .circle)
                }
            }
        }
    }
    
    private var chatList: some View {
        VStack {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .fontWeight(.semibold)
                .foregroundStyle(.primary.opacity(0.6))
                .padding(.bottom)
                .symbolEffect(.breathe.plain.wholeSymbol, options: .repeat(.continuous))
            Text("Your knowledge begins here.")
                .fontWeight(.semibold)
                .foregroundStyle(.primary.opacity(0.6))
            Text("Tap the + icon to start a new chat.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    private var bottomBar: some View {
        GlassEffectContainer {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundColor(.gray)
                Text(supabaseClient.getUser()?.email ?? "")
                
                Spacer()
                
                Button {
                    Task {
                        await supabaseClient.logOut()
                    }
                } label: {
                    Label("Log out", systemImage: "person.fill.xmark")
                        .labelStyle(.iconOnly)
                        .tint(.secondary)
                }
                
            }
            .padding()
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding([.leading, .trailing])
    }
}

#Preview {
    SidebarView()
}
