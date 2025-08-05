//
//  SettingsView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/3/25.
//

import SwiftUI

struct SettingsView: View {
    @State var models: [OpenRouterModel] = ModelsList.models
    @State var selectedModel: OpenRouterModel = DefaultsManager.shared.getModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackView()
                
                List {
                    Group {
                        Section {
                            destinationCell("Profile", icon: "person.crop.circle.fill", destination: AnyView(CreateProfileView()))
                        }
                        
                        Section {
                            modelPickerCell("Default model", icon: "gear")
                            actionCell("Theme color", icon: "swatchpalette.fill") {}
                        }
                        
                        Section {
                            actionCell("Log out", icon: "person.slash.fill", action: logOut)
                            actionCell("Delete account", icon: "trash.fill") {}
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedModel) { _, newValue in
            DefaultsManager.shared.saveModel(newValue)
        }
    }
    
    private func destinationCell(
        _ value: String,
        icon: String,
        destination: AnyView
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.default)
                Spacer()
            }
        }
        .tint(.primary)
    }
    
    private func actionCell(
        _ value: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.default)
                Spacer()
            }
        }
        .tint(.primary)
    }
    
    private func modelPickerCell(
        _ value: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.default)
                Spacer()
                
                Picker("", selection: $selectedModel) {
                    ForEach(models, id: \.code) { model in
                        Text(model.code)
                            .tag(model)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text("This will be the default model selected when you start a new chat")
                .foregroundStyle(.secondary)
        }
        .tint(.primary)
    }
    
    private func logOut() {
        Task {
            await SupabaseManager.shared.logOut()
        }
    }
    
}

#Preview {
    SettingsView()
}
