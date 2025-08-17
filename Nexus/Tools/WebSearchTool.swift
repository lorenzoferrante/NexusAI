//
//  WebSearchTool.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 11/08/25.
//

import Foundation
import Auth

struct WebSearchTool: Tool {
    let name = "search_web"
    let description = "Search the web for up-to date informations."
    let type = ToolType.webSearch
    
    var parameters: [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Query to feed to a search engine"
                ]
            ],
            "required": ["query"]
        ]
    }
    
    func execute(arguments: String, others: String?) async throws -> String {
        // Parse arguments: accept either a JSON object {"query": "..."} or a raw string as the query.
        struct Args: Decodable { let query: String }
        
        let query: String
        if let data = arguments.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(Args.self, from: data) {
            query = decoded.query
        } else {
            query = arguments
        }
        
        var userQuery: String? = nil
        if let others = others {
            userQuery = others
        }
        
        // Execute search
        let results = try await SupabaseManager.shared.search(query: query, numResults: 5)
        if results.isEmpty { return "No results found." }
        
        
        // Summarize each result (concurrently). Avoid async in .map by using a task group.
        let summaries: [String] = try await withThrowingTaskGroup(of: String.self) { group in
            for result in results {
                group.addTask {
                    let url = result.url
                    let content = (result.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    debugPrint("[DEBUG - execute] Generating summary for: \(url)")
                    
                    // Use the user query for the 'from' parameter (not the URL).
                    if let summary = try await OpenRouterAPI.shared.generateQuickSummary(from: userQuery ?? "", url: url, content: content)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) {
                        return summary
                    }
                    return "No summary available for this result."
                }
            }
            
            var collected: [String] = []
            for try await s in group { collected.append(s) }
            return collected
        }
        
        return summaries.joined(separator: "\n")
    }
}
