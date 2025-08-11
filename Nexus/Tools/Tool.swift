//
//  Tool.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 11/08/25.
//

import Foundation

// MARK: - Tool Protocol
/// Protocol defining the interface for all tools
protocol Tool {
    /// Unique name for the tool (used in function calls)
    var name: String { get }
    
    /// Description of what the tool does
    var description: String { get }
    
    /// JSON Schema parameters for the tool
    var parameters: [String: Any] { get }
    
    /// Type of the tool for UI/logging purposes
    var type: ToolType { get }
    
    /// Execute the tool with the given arguments (as JSON string)
    func execute(arguments: String) async throws -> String
}

// MARK: - Tool Extensions
extension Tool {
    /// Convert tool to OpenAI/OpenRouter function format
    func asFunctionDefinition() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters
            ]
        ]
    }
    
    /// Get UI info for this tool
    func getInfo() -> [String] {
        switch type {
        case .webSearch:
            return ["Performing web search", "network"]
        case .genericTool:
            return ["Performing tool call", "cpu.fill"]
        }
    }
}
