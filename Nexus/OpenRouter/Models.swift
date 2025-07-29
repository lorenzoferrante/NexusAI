//
//  Models.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation

enum Models: String, CaseIterable, Codable {
    /// Auto Model
    case openrouter_auto = "openrouter/auto"
    
    /// GML Models
    case glm_4_5 = "z-ai/glm-4.5"
    case glm_4_5_air = "z-ai/glm-4.5-air"
    
    /// QWEN Models
    case qwen3_235b_a22b_thinking_2507 = "qwen/qwen3-235b-a22b-thinking-2507"
    case qwen3_coder = "qwen/qwen3-coder"
    
    /// Google Gemini Models
    case gemini_2_5_flash_lite = "google/gemini-2.5-flash-lite"
    case gemini_2_5_pro = "google/gemini-2.5-pro"
    
    /// OpenAI Models
    case gpt_4_1_mini = "openai/gpt-4.1-mini"
    case gpt_4_1 = "openai/gpt-4.1"
    case gpt_4o = "openai/gpt-4o"
    case o3 = "openai/o3"
    case o4_mini_high = "openai/o4-mini-high"
}
