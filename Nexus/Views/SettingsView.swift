//
//  SettingsView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/3/25.
//

import SwiftUI

struct SettingsView: View {
    // MARK: - Models
    @State var models: [OpenRouterModel] = ModelsList.models
    @State var selectedModel: OpenRouterModel = DefaultsManager.shared.getModel()
    @State var selectedReasoningEffort: String = DefaultsManager.shared.getReasoningEffort()
    @State var isReasoningEnabled: Bool = DefaultsManager.shared.getReasoningEnabled()
    @State var efforts = ReasoningEffort.allCases
    
    // MARK: - App Theme
    @State var selectedThemeColor: ThemeColors = DefaultsManager.shared.getThemeColor()
    
    // MARK: - Tools
    @State var isWebSearchEnabled: Bool = DefaultsManager.shared.getWebSearchEnabled()
    @State var isCalendarEnabled: Bool = false
    @State var isReminderEnabled: Bool = false
    
    @State var credits: Double = 0.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackView()
                
                List {
                    Group {
                        Section(header: Text("Personal Area")) {
                            destinationCell("Profile", icon: "person.crop.circle.fill", destination: AnyView(CreateProfileView()))
                            creditsCell()
                        }
                        
                        Section(header: Text("Model Settings")) {
                            modelPickerCell("Default model", icon: "sparkles")
                            toggleCell(title: "Enable reasoning", isOn: $isReasoningEnabled, subtitle: "Some models may use reasoning to improve their performance.")
                            if isReasoningEnabled {
                                reasoningEffortCell("Reasoning effort", icon: "brain.fill")
                            }
                        }
                        
                        Section(header: Text("Tools")) {
                            toggleCell(icon: "network", title: "Web search", isOn: $isWebSearchEnabled, subtitle: "The model will be able to search the web for up-to-date informations.")
                            toggleCell(icon: "calendar.badge", title: "Calendar access", isOn: $isCalendarEnabled, subtitle: "The model will be able to add events to your calendar.")
                            toggleCell(icon: "bell.badge.fill", title: "Reminder access", isOn: $isReminderEnabled, subtitle: "The model will be able to add reminders.")
                                .disabled(true)
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
            isReasoningEnabled = newValue
            DefaultsManager.shared.saveReasoningEnabled(newValue)
        }
        .onChange(of: isWebSearchEnabled) { _, newValue in
            isWebSearchEnabled = newValue
            DefaultsManager.shared.saveWebSearchEnabled(newValue)
        }
        .onAppear {
            Task {
                isCalendarEnabled = await CalendarManager.shared.requestAccess()
                credits = try await OpenRouterAPI.shared.getCreditsRequest()
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
                .font(.caption)
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
    
    private func toggleCell(
        icon: String? = nil,
        title: String,
        isOn: Binding<Bool>,
        subtitle: String? = nil
    ) -> some View {
        VStack(alignment: .leading) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                }
                Toggle(title, isOn: isOn)
            }
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
    
    private func creditsCell() -> some View {
        HStack {
            Image(systemName: "creditcard.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text("Credits")
                .font(.default)
            Spacer()
            
            Text("\(credits, format: .currency(code: "USD"))")
                .fontDesign(.rounded)
        }
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
