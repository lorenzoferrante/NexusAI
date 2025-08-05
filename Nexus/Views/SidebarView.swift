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
    @State private var isSettingsPresented = false
    @State private var createNewChat: Bool = false
    @State private var presentAlert: Bool = false
    
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
        .navigationTitle("Mercury AI")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        // Create new chat
                        _ = try await supabaseClient.createNewChat()
                        createNewChat.toggle()
                    }
                } label: {
                    Label("", systemImage: "plus")
                        .glassEffect(in: .circle)
                }
            }
        }
        .navigationDestination(isPresented: $createNewChat) {
            ContentView()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .onAppear {
            Task {
                try await supabaseClient.retriveChats()
            }
        }
        .alert(
            "Are you sure you want to delete this chat?",
            isPresented: $presentAlert) {
                Button("Delete") {
                    
                }
            }
    }
    
    private var chatList: some View {
        Group {
            if supabaseClient.chats.count > 0 {
                List {
                    ForEach(supabaseClient.chats) { chat in
                        Button {
                            Task {
                                try await supabaseClient.loadChatWith(chat.id)
                                createNewChat.toggle()
                            }
                        } label: {
                            chatTitle(chat)
                        }
                        .tint(.primary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
                    }
                    .onDelete(perform: deleteChat)
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            } else {
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
        }
    }
    
    private func chatTitle(_ chat: Chat) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(chat.title ?? "Chat with \(chat.model)")
                Text(DateUtils.daySince(chat.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
    
    private var bottomBar: some View {
        GlassEffectContainer {
            HStack {
                Button {
                    isSettingsPresented.toggle()
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.gray)
                    Text(supabaseClient.profile?.username ?? "")
                }
                .tint(.primary)
                
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
        .preferredColorScheme(.dark)
    }
    
    private func deleteChat(at offest: IndexSet) {
        guard let index = offest.first else {
            return
        }
        debugPrint("[DEBUG] Delete chat at: \(index)")
    }
}

#Preview {
    SidebarView()
}
