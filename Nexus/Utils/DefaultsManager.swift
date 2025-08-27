//
//  DefaultsManager.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation
import SwiftUI

enum ReasoningEffort: String, CaseIterable {
    case low
    case medium
    case high
}

@Observable
class DefaultsManager {
    
    static let shared = DefaultsManager()
    
    /// Model
    private let selectedModelKey = "selectedModel"
    private let reasoningEffort = "reasoningEffort"
    private let reasoningEnabled = "reasoningEnabled"
    
    /// Theme
    private let themeColor = "themeColor"
    
    /// Tools
    private let webSearchEnabled = "webSearchEnabled"
    private let calendarEnabled = "calendarEnabled"
    private let reminderEnabled = "reminderEnabled"
    
    var selectedReasoningEffort: String
    var isReasoningEnabled: Bool
    
    var selectedThemeColor: ThemeColors
    
    var isWebSearchEnabled: Bool
    var isCalendarEnabled: Bool
    var isReminderEnabled: Bool
    
    /// MARK: - Init
    private init() {
        if let colorString = UserDefaults.standard.string(forKey: themeColor),
           let themeColor = ThemeColors(rawValue: colorString) {
            self.selectedThemeColor = themeColor
        } else {
            self.selectedThemeColor = .bronze
        }
        
        selectedReasoningEffort = ReasoningEffort.medium.rawValue
        isReasoningEnabled = true
        
        isWebSearchEnabled = true
        isCalendarEnabled = false
        isReminderEnabled = false
    }
    
    /// MARK: - Model
    func saveModel(_ model: OpenRouterModelRow) {
        UserDefaults.standard.set(model.code, forKey: selectedModelKey)
    }
    
    @MainActor
    func getModel() -> OpenRouterModelRow {
        if let openRouterModelCode = UserDefaults.standard.object(forKey: selectedModelKey) as? String,
           let model = SupabaseManager.shared.models.first(where: { $0.code == openRouterModelCode }) {
            print("[DEBUG] Returining \(model.code)")
            return model
        }
        print("[DEBUG] Returining openrouter/auto")
        return SupabaseManager.shared.models.first(where: { $0.code == "openai/gpt-5-mini" })!
    }
    
    func saveReasoningEffort(_ effort: ReasoningEffort) {
        withAnimation {
            self.selectedReasoningEffort = effort.rawValue
            UserDefaults.standard.set(effort.rawValue, forKey: reasoningEffort)
        }
    }
    
    func getReasoningEffort() -> String {
        if let effort = UserDefaults.standard.string(forKey: reasoningEffort) {
            return effort
        }
        return ReasoningEffort.medium.rawValue
    }
    
    func getReasoningEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: reasoningEnabled)
    }
    
    func saveReasoningEnabled(_ isEnabled: Bool) {
        withAnimation {
            self.isReasoningEnabled = isEnabled
            UserDefaults.standard.set(isEnabled, forKey: reasoningEnabled)
        }
    }
    
    /// MARK: - Theme
    func saveThemeColor(_ color: ThemeColors) {
        withAnimation {
            self.selectedThemeColor = color
            UserDefaults.standard.set(color.rawValue, forKey: themeColor)
        }
    }
    
    func getThemeColor() -> ThemeColors {
        if let colorString = UserDefaults.standard.string(forKey: themeColor),
           let themeColor = ThemeColors(rawValue: colorString) {
            return themeColor
        }
        return .bronze
    }
    
    /// MARK: - Tools
    func getCalendarEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: calendarEnabled)
    }
    
    func saveCalendarEnabled(_ isEnabled: Bool) {
        withAnimation {
            self.isCalendarEnabled = isEnabled
            UserDefaults.standard.set(isEnabled, forKey: calendarEnabled)
        }
    }
    
    func getWebSearchEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: webSearchEnabled)
    }
    
    func saveWebSearchEnabled(_ isEnabled: Bool) {
        withAnimation {
            self.isWebSearchEnabled = isEnabled
            UserDefaults.standard.set(isEnabled, forKey: webSearchEnabled)
        }
    }
    
    
}
