//
//  CrawlTool.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 16/08/25.
//

import Foundation

struct CrawlTool: Tool {
    var name: String = "crawl_webpage"
    
    var description: String = "Obtain the content of a webpages with specified urls"
    
    var parameters: [String: Any] {
        [
            "type": "object",
            "properties": [
                "urls": [
                    "type": "array",
                    "description": "array containing the urls of the webpages"
                ]
            ],
            "required": ["urls"]
        ]
    }
    
    var type: ToolType = .crawlTool
    
    func execute(arguments: String, others: String?) async throws -> String {
        struct Args: Decodable { let urls: [String] }
        
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
        
        let exaClient = ExaClient()
        let results = try await exaClient.crawl(ids: urls)
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
