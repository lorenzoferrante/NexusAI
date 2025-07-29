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
    
    func saveModel(_ model: Models) {
        UserDefaults.standard.set(model.rawValue, forKey: selectedModelKey)
    }
    
    func getModel() -> Models {
        if let rawValue = UserDefaults.standard.string(forKey: selectedModelKey),
           let model = Models.allCases.first(where: { $0.rawValue == rawValue }) {
            return model
        }
        return .glm_4_5_air
    }
    
}
