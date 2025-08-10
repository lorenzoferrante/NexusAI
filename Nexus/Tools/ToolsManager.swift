//
//  ToolsManager.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 08/08/25.
//

import Foundation

enum ToolType {
    case webSearch
    case genericTool
}

class ToolsManager {
    
    func makeFunctionTool(
        name: String,
        description: String,
        parameters: [String: Any]   // JSON Schema
    ) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters
            ]
        ]
    }
    
    /// MARK: - Web Search
    func makeWebSearchTool() -> [String: Any] {
        return makeFunctionTool(
            name: "search_web",
            description: "Search the web for up-to date informations",
            parameters: [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "Query to feed to a search engine"
                    ]
                ],
                "required": ["query"]
            ]
        )
    }
    
    func executeWebSearch(_ query: String) async throws -> String {
        let results = try await ExaClient().search(query: query, numResults: 5)
        
        let formatted = results.map { result -> String in
            let titleTrimmed = result.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let titleOrHost: String = {
                if let t = titleTrimmed, !t.isEmpty { return t }
                return URL(string: result.url)?.host ?? result.url
            }()
            let content = (result.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(titleOrHost) - \(result.url)\n\(content)"
        }
        .joined(separator: "\n\n")
        
        return formatted
    }
    
    public func getToolTypeFrom(_ name: String) -> ToolType {
        switch name {
        case "search_web":
            return .webSearch
        default:
            return .genericTool
        }
    }
    
    public func getInfoFor(_ toolType: ToolType) -> [String] {
        switch toolType {
        case .webSearch:
            return ["Performing web search", "network"]
        case .genericTool:
            return ["Performing tool call", "cpu.fill"]
        }
    }
}
