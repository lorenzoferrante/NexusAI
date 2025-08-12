//
//  DocLookupTool.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 12/08/25.
//

import Foundation

struct DocLookupTool: Tool {
    var name: String = "doc_lookup"
    
    var description: String = "After a web search, you can use this command to get the content of the page."
    
    var parameters: [String: Any] {
        [
            "type": "object",
            "properties": [
                "docID": [
                    "type": "string",
                    "description": "ID for the document to lookup"
                ]
            ],
            "required": ["docID"]
        ]
    }
    
    var type: ToolType = .docLookUp
    
    func execute(arguments: String, others: String?) async throws -> String {
        struct Args: Decodable { let docID: String }
        
        let docID: String
        if let data = arguments.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(Args.self, from: data) {
            docID = decoded.docID
        } else {
            docID = arguments
        }
        
        var userQuery: String? = nil
        if let others = others {
            userQuery = others
        }
        
        let fileURLString = await SupabaseManager.shared.retrieveFileURLFrom(docID)
        guard let fileURL = URL(string: fileURLString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: fileURL)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // If you want the file content as a String (assuming it's text)
        guard let fileContent = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        let summary = try await OpenRouterAPI.shared.generateQuickSummary(from: userQuery ?? "", url: "", content: fileContent)
        
        return summary ?? "No summary available for this result."
    }
    
    
}
