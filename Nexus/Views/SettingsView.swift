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
    @State var selectedThemeColor: ThemeColors = DefaultsManager.shared.getThemeColor()
    @State var selectedReasoningEffort: String = DefaultsManager.shared.getReasoningEffort()
    @State var isReasoningEnabled: Bool = DefaultsManager.shared.getReasoningEnabled()
    @State var efforts = ReasoningEffort.allCases
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackView()
                
                List {
                    Group {
                        Section(header: Text("Personal Area")) {
                            destinationCell("Profile", icon: "person.crop.circle.fill", destination: AnyView(CreateProfileView()))
                        }
                        
                        Section(header: Text("Model Settings")) {
                            modelPickerCell("Default model", icon: "sparkles")
                            toggleCell()
                            if isReasoningEnabled {
                                reasoningEffortCell("Reasoning effort", icon: "brain.fill")
                            }
                        }
                        
                        Section(header: Text("App Settings")) {
                            themeCell("Theme color", icon: "swatchpalette.fill") {}
                        }
                        
                        Section(header: Text("Warning Zone")) {
                            actionCell("Log out", icon: "person.slash.fill", action: logOut)
                            actionCell("Delete account", icon: "trash.fill", isDestructive: true) {}
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
        .onChange(of: selectedThemeColor) { _, newValue in
            DefaultsManager.shared.saveThemeColor(newValue)
        }
        .onChange(of: selectedReasoningEffort) { _, newValue in
            DefaultsManager.shared.saveReasoningEffort(ReasoningEffort(rawValue: newValue) ?? ReasoningEffort.medium)
        }
        .onChange(of: isReasoningEnabled) { _, newValue in
            withAnimation {
                isReasoningEnabled = newValue
                DefaultsManager.shared.saveReasoningEnabled(newValue)
            }
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
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isDestructive ? .red : .secondary)
                Text(value)
                    .font(.default)
                    .tint(isDestructive ? .red : .primary)
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
                    }
                }
            }
            Text("This will be the default model selected when you start a new chat")
                .foregroundStyle(.secondary)
        }
        .tint(.primary)
    }
    
    private func themeCell(
        _ value: String,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isDestructive ? .red : .secondary)
                Text(value)
                    .font(.default)
                    .tint(isDestructive ? .red : .primary)
                Spacer()
                
                Menu {
                    Picker("", selection: $selectedThemeColor) {
                        ForEach(ThemeColors.allCases, id: \.self) { color in
                            Text(ThemeColors.toString(color: color))
                                .tag(color)
                        }
                    }
                } label: {
                    Circle()
                        .fill(ThemeColors.from(color: selectedThemeColor))
                        .frame(width: 20)
                }
                
            }
        }
        .tint(.primary)
    }
    
    private func toggleCell() -> some View {
        VStack(alignment: .leading) {
            Toggle("Enable reasoning", isOn: $isReasoningEnabled)
            Text("Some models may use reasoning to improve their performance.")
                .foregroundStyle(.secondary)
        }
    }
    
    private func reasoningEffortCell(
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
                
                Picker("", selection: $selectedReasoningEffort) {
                    ForEach(efforts, id: \.rawValue) { effort in
                        Text(effort.rawValue.capitalized)
                            .tag(effort)
                    }
                }
            }
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
