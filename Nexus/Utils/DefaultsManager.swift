//
//  DefaultsManager.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation

@Observable
class DefaultsManager {
    
    static let shared = DefaultsManager()
    private let selectedModelKey = "selectedModel"
    
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
    
}
