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
    @State private var indexToDelete: Int? = nil
    
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        ZStack {
            BackView()
                .ignoresSafeArea()
            
            chatList
            
            VStack {
                Spacer()
                bottomBar
            }
                        
        }
        .navigationTitle("Mercury AI")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        feedbackGenerator.impactOccurred()
                        _ = try await supabaseClient.createNewChat()
                        createNewChat.toggle()
                    }
                } label: {
                    Label("", systemImage: "plus")
                        .glassEffect(in: .circle)
                }
            }
        }
        .toolbarTitleDisplayMode(.inlineLarge)
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
        .preferredColorScheme(.dark)
        .alert(
            "Are you sure you want to delete this chat?",
            isPresented: $presentAlert,
            presenting: indexToDelete
        ) { index in
            Button("Cancel", role: .cancel) {
                presentAlert.toggle()
            }
            Button("Delete", role: .destructive) {
                supabaseClient.deleteChat(at: index)
            }
        } message: { _ in
            Text("This action cannot be undone.")
        }
    }
    
    private var chatList: some View {
        Group {
            if supabaseClient.chats.count > 0 {
                List {
                    ForEach(supabaseClient.chats) { chat in
                        Button {
                            Task {
                                feedbackGenerator.impactOccurred()
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
        HStack {
            Button {
                feedbackGenerator.impactOccurred()
                isSettingsPresented.toggle()
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundColor(.gray)
                Text(supabaseClient.profile?.username ?? "")
            }
            .foregroundStyle(.white)
//            .tint(.white)
            .padding()
            .glassEffect(.regular.interactive(), in: .capsule)
            
            Spacer()
        }
        .padding()
    }
    
    private func deleteChat(at offest: IndexSet) {
        guard let index = offest.first else {
            return
        }
        indexToDelete = index
        
        feedbackGenerator.impactOccurred()
        presentAlert.toggle()
    }
}

#Preview {
    NavigationStack {
        SidebarView()
    }
}
