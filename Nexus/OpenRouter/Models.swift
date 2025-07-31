//
//  Models.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation

enum Providers: String, CaseIterable, Codable {
    case openrouter = "OpenRouter"
    case perplexity = "Perplexity"
    case zai = "Z-AI"
    case qwen = "Qwen"
    case google = "Google"
    case xAI = "xAI"
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
}

struct OpenRouterModel: Codable, Hashable {
    var name: String
    var provider: Providers
    var description: String?
    var code: String
}

//enum Models: String, CaseIterable, Codable {
//    /// Auto Model
//    case openrouter_auto = "openrouter/auto"
//    
//    /// OpenRouter Models
//    case horizon_alpha = "openrouter/horizon-alpha"
//    
//    /// Perplexity Models
//    case sonar_deep_research = "perplexity/sonar-deep-research"
//    case sonar = "perplexity/sonar"
//    case sonar_pro = "perplexity/sonar-pro"
//    case sonar_reasoning = "perplexity/sonar-reasoning"
//    case sonar_reasoning_pro = "perplexity/sonar-reasoning-pro"
//    
//    /// GML Models
//    case glm_4_5 = "z-ai/glm-4.5"
//    case glm_4_5_air = "z-ai/glm-4.5-air"
//    
//    /// QWEN Models
//    case qwen3_235b_a22b_thinking_2507 = "qwen/qwen3-235b-a22b-thinking-2507"
//    case qwen3_coder = "qwen/qwen3-coder"
//    
//    /// Google Gemini Models
//    case gemini_2_5_flash_lite = "google/gemini-2.5-flash-lite"
//    case gemini_2_5_pro = "google/gemini-2.5-pro"
//    
//    /// OpenAI Models
//    case gpt_4_1_mini = "openai/gpt-4.1-mini"
//    case gpt_4_1 = "openai/gpt-4.1"
//    case gpt_4o = "openai/gpt-4o"
//    case o3_mini = "openai/o3-mini"
//    case o4_mini_high = "openai/o4-mini-high"
//    
//    /// Anthropic Models
//    case claude_sonnet_4 = "anthropic/claude-sonnet-4"
//    case claude_opus_4 = "anthropic/claude-opus-4"
//}

class ModelsList {
    enum Models {
        case model(OpenRouterModel)
    }
    
    static let models = [
        OpenRouterModel(name: "Auto", provider: .openrouter, description: "Automatically selects the best model.", code: "openrouter/auto"),
        OpenRouterModel(name: "Horizon Alpha", provider: .openrouter, description: "Alpha version of Horizon model.", code: "openrouter/horizon-alpha"),
        OpenRouterModel(name: "Sonar Deep Research", provider: .perplexity, description: "Deep research model by Perplexity.", code: "perplexity/sonar-deep-research"),
        OpenRouterModel(name: "Sonar", provider: .perplexity, description: "Standard Sonar model.", code: "perplexity/sonar"),
        OpenRouterModel(name: "Sonar Pro", provider: .perplexity, description: "Pro version of Sonar model.", code: "perplexity/sonar-pro"),
        OpenRouterModel(name: "Sonar Reasoning", provider: .perplexity, description: "Reasoning enhanced Sonar model.", code: "perplexity/sonar-reasoning"),
        OpenRouterModel(name: "Sonar Reasoning Pro", provider: .perplexity, description: "Pro reasoning Sonar model.", code: "perplexity/sonar-reasoning-pro"),
        OpenRouterModel(name: "GLM 4.5", provider: .zai, description: "GLM version 4.5 by Z-AI.", code: "z-ai/glm-4.5"),
        OpenRouterModel(name: "GLM 4.5 Air", provider: .zai, description: "Air variant of GLM 4.5.", code: "z-ai/glm-4.5-air"),
        OpenRouterModel(name: "Qwen3 235B A22B Thinking 2507", provider: .qwen, description: "Advanced Qwen thinking model.", code: "qwen/qwen3-235b-a22b-thinking-2507"),
        OpenRouterModel(name: "Qwen3 Coder", provider: .qwen, description: "Coder model by Qwen.", code: "qwen/qwen3-coder"),
        OpenRouterModel(name: "Gemini 2.5 Flash Lite", provider: .google, description: "Lite version of Gemini 2.5 Flash.", code: "google/gemini-2.5-flash-lite"),
        OpenRouterModel(name: "Gemini 2.5 Pro", provider: .google, description: "Pro version of Gemini 2.5.", code: "google/gemini-2.5-pro"),
        OpenRouterModel(name: "GPT 4.1 Mini", provider: .openAI, description: "Mini variant of GPT 4.1.", code: "openai/gpt-4.1-mini"),
        OpenRouterModel(name: "GPT 4.1", provider: .openAI, description: "Standard GPT 4.1 model.", code: "openai/gpt-4.1"),
        OpenRouterModel(name: "GPT 4o", provider: .openAI, description: "GPT 4o model variant.", code: "openai/gpt-4o"),
        OpenRouterModel(name: "O3 Mini", provider: .openAI, description: "Mini version of O3.", code: "openai/o3-mini"),
        OpenRouterModel(name: "O4 Mini High", provider: .openAI, description: "High performance O4 mini.", code: "openai/o4-mini-high"),
        OpenRouterModel(name: "Claude Sonnet 4", provider: .anthropic, description: "Sonnet 4 model by Anthropic.", code: "anthropic/claude-sonnet-4"),
        OpenRouterModel(name: "Claude Opus 4", provider: .anthropic, description: "Opus 4 model by Anthropic.", code: "anthropic/claude-opus-4"),
    ]
}
