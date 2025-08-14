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
        OpenRouterModel(name: "Horizon Beta", provider: .openrouter, description: "Alpha version of Horizon model.", code: "openrouter/horizon-beta"),
        
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
        OpenRouterModel(name: "Qwen3 14B (free)", provider: .qwen, description: "Qwen3-14B is a dense 14.8B parameter causal language model from the Qwen3 series.", code: "qwen/qwen3-14b:free"),
        OpenRouterModel(name: "Qwen3 235B A22B Thinking 2507", provider: .qwen, description: "Advanced Qwen thinking model.", code: "qwen/qwen3-235b-a22b-thinking-2507"),
        OpenRouterModel(name: "Qwen3 Coder", provider: .qwen, description: "Coder model by Qwen.", code: "qwen/qwen3-coder"),
        
        /// Google Models
        OpenRouterModel(name: "Gemma 3 27B", provider: .google, description: "Gemma 3 27B is Google's latest open source model.", code: "google/gemma-3-27b-it"),
        OpenRouterModel(name: "Gemini 2.5 Flash", provider: .google, description: "Gemini 2.5 Flash is Google's state-of-the-art workhorse model.", code: "google/gemini-2.5-flash"),
        OpenRouterModel(name: "Gemini 2.5 Flash Lite", provider: .google, description: "Lite version of Gemini 2.5 Flash.", code: "google/gemini-2.5-flash-lite"),
        OpenRouterModel(name: "Gemini 2.5 Pro", provider: .google, description: "Pro version of Gemini 2.5.", code: "google/gemini-2.5-pro"),
        
        /// OpenAI Models
        OpenRouterModel(name: "GPT-5", provider: .openAI, description: "GPT-5 is OpenAI’s most advanced model, offering major improvements in reasoning, code quality, and user experience.", code: "openai/gpt-5"),
        OpenRouterModel(name: "GPT-5 Chat", provider: .openAI, description: "GPT-5 is OpenAI’s most advanced model, offering major improvements in reasoning, code quality, and user experience.", code: "openai/gpt-5-chat"),
        OpenRouterModel(name: "GPT-5 Mini", provider: .openAI, description: "GPT-5 is OpenAI’s most advanced model, offering major improvements in reasoning, code quality, and user experience.", code: "openai/gpt-5-mini"),
        OpenRouterModel(name: "GPT-5 Nano", provider: .openAI, description: "GPT-5 is OpenAI’s most advanced model, offering major improvements in reasoning, code quality, and user experience.", code: "openai/gpt-5-nano"),
        OpenRouterModel(name: "o3", provider: .openAI, description: "o3 is a well-rounded and powerful model across domains. It sets a new standard for math, science, coding, and visual reasoning tasks.", code: "openai/o3"),
        OpenRouterModel(name: "GPT-4.1", provider: .openAI, description: "GPT-4.1 is a flagship large language model optimized for advanced instruction following, real-world software engineering, and long-context reasoning.", code: "openai/gpt-4.1"),
        OpenRouterModel(name: "GPT-4o", provider: .openAI, description: "GPT-5 is OpenAI’s most advanced model, offering major improvements in reasoning, code quality, and user experience.", code: "openai/gpt-4o"),
        OpenRouterModel(name: "GPT OSS 120B", provider: .openAI, description: "gpt-oss-120b is an open-weight, 117B-parameter Mixture-of-Experts (MoE) language model from OpenAI designed for high-reasoning, agentic, and general-purpose production use cases.", code: "openai/gpt-oss-120b"),
        OpenRouterModel(name: "GPT OSS 20B", provider: .openAI, description: "gpt-oss-20b is an open-weight 21B parameter model released by OpenAI under the Apache 2.0 license.", code: "openai/gpt-oss-20b"),
        
        /// Anthropic Models
        OpenRouterModel(name: "Claude Sonnet 4", provider: .anthropic, description: "Sonnet 4 model by Anthropic.", code: "anthropic/claude-sonnet-4"),
        OpenRouterModel(name: "Claude Opus 4", provider: .anthropic, description: "Opus 4 model by Anthropic.", code: "anthropic/claude-opus-4"),
        OpenRouterModel(name: "Claude Opus 4.1", provider: .anthropic, description: "Opus 4.1 model by Anthropic.", code: "anthropic/claude-opus-4.1"),
        
        /// xAI Models
        OpenRouterModel(name: "Grok 4", provider: .xAI, description: "", code: "x-ai/grok-4"),
        OpenRouterModel(name: "Grok 3", provider: .xAI, description: "", code: "x-ai/grok-3"),
        OpenRouterModel(name: "Grok 3 Mini", provider: .xAI, description: "", code: "x-ai/grok-3-mini"),
        
        /// DeepSeek Models
        OpenRouterModel(name: "DeepSeek V3 0324", provider: .deepseek, description: "", code: "deepseek/deepseek-chat-v3-0324"),
        OpenRouterModel(name: "R1", provider: .deepseek, description: "", code: "deepseek/deepseek-r1"),
        OpenRouterModel(name: "R1 Distill Qwen 7B", provider: .deepseek, description: "", code: "deepseek/deepseek-r1-distill-qwen-7b"),
        OpenRouterModel(name: "R1 0528 Qwen3 8B", provider: .deepseek, description: "", code: "deepseek/deepseek-r1-0528-qwen3-8b"),
        OpenRouterModel(name: "R1 0528", provider: .deepseek, description: "", code: "deepseek/deepseek-r1-0528"),
        OpenRouterModel(name: "R1 Distill Qwen 32B", provider: .deepseek, description: "", code: "deepseek/deepseek-r1-distill-qwen-32b"),
        OpenRouterModel(name: "R1 Distill Llama 70B", provider: .deepseek, description: "", code: "deepseek/deepseek-r1-distill-llama-70b"),
        
        /// Moonshot Models
        OpenRouterModel(name: "Kimi K2", provider: .moonshot, description: "", code: "moonshotai/kimi-k2"),
        
        /// AI21 Models
        OpenRouterModel(name: "Jamba Mini 1.7", provider: .ai21, description: "", code: "ai21/jamba-mini-1.7"),
        OpenRouterModel(name: "Jamba Large 1.7", provider: .ai21, description: "", code: "ai21/jamba-large-1.7"),
    ]
}
