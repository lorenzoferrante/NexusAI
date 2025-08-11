//
//  WebSearchTool.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 11/08/25.
//

import Foundation

struct WebSearchTool: Tool {
    let name = "search_web"
    let description = "Search the web for up-to date informations"
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
    
    func execute(arguments: String) async throws -> String {
        // Parse arguments
        struct Args: Decodable { let query: String }
        let args = try JSONDecoder().decode(Args.self, from: Data(arguments.utf8))
        
        // Execute search
        let results = try await ExaClient().search(query: args.query, numResults: 5)
        
        // Format results
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
}
