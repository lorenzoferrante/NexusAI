//
//  ModelItem.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/27/25.
//

import Foundation
import Supabase
import SwiftUI

enum Providers: String, CaseIterable, Codable {
    case openrouter = "OpenRouter"
    case perplexity = "Perplexity"
    case zai = "Z-AI"
    case qwen = "Qwen"
    case google = "Google"
    case xAI = "xAI"
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case deepseek = "DeepSeek"
    case moonshot = "Moonshot"
    case ai21 = "AI21"
    
    func icon() -> Image {
        switch self {
        case .openrouter:
            return Image(.openrouter)
        case .perplexity:
            return Image(.perplexity)
        case .zai:
            return Image(.zAi)
        case .qwen:
            return Image(.qwen)
        case .google:
            return Image(.google)
        case .xAI:
            return Image(.xai)
        case .openAI:
            return Image(.openai)
        case .anthropic:
            return Image(.anthropic)
        case .deepseek:
            return Image(.deepseek)
        case .moonshot:
            return Image(.moonshot)
        case .ai21:
            return Image(.ai21)
        }
    }
}

// MARK: - DB row (matches the SQL schema)
struct OpenRouterModelRow: Codable, Identifiable, Hashable {
    let name: String
    let provider: String
    let description: String?
    let code: String
    let toolUse: Bool?
    let inputModalities: String?
    let outputModalities: String?
    let reasoning: Bool?

    var id: String { code }

    enum CodingKeys: String, CodingKey {
        case name
        case provider
        case description
        case code
        case toolUse = "tool_use"
        case inputModalities = "input_modalities"
        case outputModalities = "output_modalities"
        case reasoning
    }
    
    func toProvider() -> Providers {
        return Providers(rawValue: provider) ?? .openrouter
    }
}

// MARK: - Mapping DB row -> your app model
//extension OpenRouterModelRow {
//    init(row: OpenRouterModelRow) {
//        self.name = row.name
//        self.provider = Providers(rawValue: row.provider) ?? .openrouter
//        self.description = row.description
//        self.code = row.code
//        self.toolUse = row.toolUse
//        self.inputModalities = row.inputModalities
//        self.outputModalities = row.outputModalities
//        self.reasoning = row.reasoning
//    }
//}
