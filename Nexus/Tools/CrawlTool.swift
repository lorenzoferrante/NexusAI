//
//  CrawlTool.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 16/08/25.
//

import Foundation

struct CrawlTool: Tool {
    let name: String = "get_webpage_info"
    let description: String = "Obtain the content of a webpages with specified urls"
    let type = ToolType.crawlTool
    
    var parameters: [String: Any] {
        [
            "type": "object",
            "properties": [
                "urls": [
                    "type": "array",
                    "description": "Array of webpage URLs to fetch",
                    "items": [
                        "type": "string",
                        "format": "uri"
                    ],
                    "minItems": 1
                ]
            ],
            "required": ["urls"],
            "additionalProperties": false
        ]
    }
    
    struct Args: Decodable { let urls: [String] }
    
    func execute(arguments: String, others: String?) async throws -> String {
        // Prefer JSON args (as per tool schema), but support legacy ";"-separated string.
        let urls: [String]
        if let data = arguments.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(Args.self, from: data) {
            urls = decoded.urls
        } else {
            urls = arguments
                .split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty  }
        }
        if urls.isEmpty {
            return "{\"error\":\"get_webpage_info: 'urls' cannot be empty.\"}"
        }
        
        let results = try await SupabaseManager.shared.crawl(ids: urls)
        var stringResults = ""
        
        for result in results {
            let resultURL = result.url
            let resultText = result.text ?? "No content available"
            
            let line = """
                URL: \(resultURL) \
                TEXT: \(resultText) \
                
                """
            stringResults.append(line)
        }
        
        return stringResults
    }
    
}
