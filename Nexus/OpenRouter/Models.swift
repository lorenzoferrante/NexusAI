//
//  Models.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation
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
        }
    }
}

struct OpenRouterModel: Codable, Hashable {
    var name: String
    var provider: Providers
    var description: String?
    var code: String
}

class ModelsList {    
    static let models = [
        /// OpenRouter Models
        OpenRouterModel(name: "Auto", provider: .openrouter, description: "Automatically selects the best model.", code: "openrouter/auto"),
        OpenRouterModel(name: "Horizon Alpha", provider: .openrouter, description: "Alpha version of Horizon model.", code: "openrouter/horizon-alpha"),
        
        /// Perplexity Models
        OpenRouterModel(name: "Sonar Deep Research", provider: .perplexity, description: "Deep research model by Perplexity.", code: "perplexity/sonar-deep-research"),
        OpenRouterModel(name: "Sonar", provider: .perplexity, description: "Standard Sonar model.", code: "perplexity/sonar"),
        OpenRouterModel(name: "Sonar Pro", provider: .perplexity, description: "Pro version of Sonar model.", code: "perplexity/sonar-pro"),
        OpenRouterModel(name: "Sonar Reasoning", provider: .perplexity, description: "Reasoning enhanced Sonar model.", code: "perplexity/sonar-reasoning"),
        OpenRouterModel(name: "Sonar Reasoning Pro", provider: .perplexity, description: "Pro reasoning Sonar model.", code: "perplexity/sonar-reasoning-pro"),
        
        /// Z-AI Models
        OpenRouterModel(name: "GLM 4.5", provider: .zai, description: "GLM version 4.5 by Z-AI.", code: "z-ai/glm-4.5"),
        OpenRouterModel(name: "GLM 4.5 Air", provider: .zai, description: "Air variant of GLM 4.5.", code: "z-ai/glm-4.5-air"),
        
        /// Qwen Models
        OpenRouterModel(name: "Qwen3 235B A22B Thinking 2507", provider: .qwen, description: "Advanced Qwen thinking model.", code: "qwen/qwen3-235b-a22b-thinking-2507"),
        OpenRouterModel(name: "Qwen3 Coder", provider: .qwen, description: "Coder model by Qwen.", code: "qwen/qwen3-coder"),
        
        /// Google Models
        OpenRouterModel(name: "Gemma 3 27B", provider: .google, description: "Gemma 3 27B is Google's latest open source model.", code: "google/gemma-3-27b-it"),
        OpenRouterModel(name: "Gemini 2.5 Flash", provider: .google, description: "Gemini 2.5 Flash is Google's state-of-the-art workhorse model.", code: "google/gemini-2.5-flash"),
        OpenRouterModel(name: "Gemini 2.5 Flash Lite", provider: .google, description: "Lite version of Gemini 2.5 Flash.", code: "google/gemini-2.5-flash-lite"),
        OpenRouterModel(name: "Gemini 2.5 Pro", provider: .google, description: "Pro version of Gemini 2.5.", code: "google/gemini-2.5-pro"),
        
        /// OpenAI Models
        OpenRouterModel(name: "GPT 4.1 Mini", provider: .openAI, description: "Mini variant of GPT 4.1.", code: "openai/gpt-4.1-mini"),
        OpenRouterModel(name: "GPT 4.1", provider: .openAI, description: "Standard GPT 4.1 model.", code: "openai/gpt-4.1"),
        OpenRouterModel(name: "GPT 4o", provider: .openAI, description: "GPT 4o model variant.", code: "openai/gpt-4o"),
        OpenRouterModel(name: "O3 Mini", provider: .openAI, description: "Mini version of O3.", code: "openai/o3-mini"),
        OpenRouterModel(name: "O4 Mini High", provider: .openAI, description: "High performance O4 mini.", code: "openai/o4-mini-high"),
        
        /// Anthropic Models
        OpenRouterModel(name: "Claude Sonnet 4", provider: .anthropic, description: "Sonnet 4 model by Anthropic.", code: "anthropic/claude-sonnet-4"),
        OpenRouterModel(name: "Claude Opus 4", provider: .anthropic, description: "Opus 4 model by Anthropic.", code: "anthropic/claude-opus-4"),
        
        /// xAI Models
        OpenRouterModel(name: "Grok 4", provider: .xAI, description: "", code: "x-ai/grok-4"),
        OpenRouterModel(name: "Grok 3", provider: .xAI, description: "", code: "x-ai/grok-3"),
        OpenRouterModel(name: "Grok 3 Mini", provider: .xAI, description: "", code: "x-ai/grok-3-mini"),
        
        /// DeepSeek Models
        OpenRouterModel(name: "R1", provider: .deepseek, description: "", code: "deepseek/deepseek-r1"),
        OpenRouterModel(name: "R1 Distill Qwen 7B", provider: .deepseek, description: "", code: "deepseek/deepseek-r1-distill-qwen-7b"),
        OpenRouterModel(name: "R1 0528 Qwen3 8B", provider: .deepseek, description: "", code: "deepseek/deepseek-r1-0528-qwen3-8b"),
        OpenRouterModel(name: "DeepSeek: R1 0528", provider: .deepseek, description: "", code: "deepseek/deepseek-r1-0528"),
        OpenRouterModel(name: "R1 Distill Qwen 32B", provider: .deepseek, description: "", code: "deepseek/deepseek-r1-distill-qwen-32b"),
        OpenRouterModel(name: "DeepSeek: R1 Distill Llama 70B", provider: .deepseek, description: "", code: "deepseek/deepseek-r1-distill-llama-70b"),
        
        /// Moonshot Models
        OpenRouterModel(name: "Kimi K2", provider: .moonshot, description: "", code: "moonshotai/kimi-k2"),
    ]
}
