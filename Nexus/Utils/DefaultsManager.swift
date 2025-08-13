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
    private let selectedModelKey = "selectedModel"
    private let themeColor = "themeColor"
    private let reasoningEffort = "reasoningEffort"
    private let reasoningEnabled = "reasoningEnabled"
    
    var selectedThemeColor: ThemeColors
    var selectedReasoningEffort: String
    var isReasoningEnabled: Bool
    
    private init() {
        if let colorString = UserDefaults.standard.string(forKey: themeColor),
           let themeColor = ThemeColors(rawValue: colorString) {
            self.selectedThemeColor = themeColor
        } else {
            self.selectedThemeColor = .bronze
        }
        
        selectedReasoningEffort = ReasoningEffort.medium.rawValue
        isReasoningEnabled = true
    }
    
    func saveModel(_ model: OpenRouterModel) {
        UserDefaults.standard.set(model.code, forKey: selectedModelKey)
    }
    
    func getModel() -> OpenRouterModel {
        if let openRouterModelCode = UserDefaults.standard.object(forKey: selectedModelKey) as? String,
           let model = ModelsList.models.first(where: { $0.code == openRouterModelCode }) {
            print("[DEBUG] Returining \(model.code)")
            return model
        }
        print("[DEBUG] Returining openrouter/auto")
        return ModelsList.models.first(where: { $0.code == "openrouter/auto" })!
    }
    
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
    
    func saveReasoningEnabled(_ isEnabled: Bool) {
        withAnimation {
            self.isReasoningEnabled = isEnabled
            UserDefaults.standard.set(isEnabled, forKey: reasoningEnabled)
        }
    }
    
    func getReasoningEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: reasoningEnabled)
    }
    
    
}
