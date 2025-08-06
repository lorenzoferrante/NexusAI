//
//  DefaultsManager.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation
import SwiftUI

@Observable
class DefaultsManager {
    
    static let shared = DefaultsManager()
    private let selectedModelKey = "selectedModel"
    private let themeColor = "themeColor"
    
    var selectedThemeColor: ThemeColors
    
    private init() {
        if let colorString = UserDefaults.standard.string(forKey: themeColor),
           let themeColor = ThemeColors(rawValue: colorString) {
            self.selectedThemeColor = themeColor
        } else {
            self.selectedThemeColor = .bronze
        }
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
    
}
