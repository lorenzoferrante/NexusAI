//
//  Message.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation

enum Role: String, Codable {
    case user
    case assistant
    case tool
}

struct ToolFunction: Codable, Hashable {
    var name: String?
    var arguments: String?
    
    func asDictionary() -> [String: Any] {
        return [
            "name": name!,
            "arguments": arguments!
        ]
    }
}

struct ToolCall: Codable, Identifiable, Hashable {
    var id: String?
    var type: String?
    var function: ToolFunction?
    
    func asDictionary() -> [String: Any] {
        return [
            "id": id!,
            "type": type!,
            "function": function!.asDictionary()
        ]
    }
}

struct Message: Codable, Identifiable, Hashable {
    var id = UUID()
    let chatId: UUID
    let role: Role
    var content: String?
    var tokenCount: Int?
    var finishReason: String?
    var imageURL: String?
    var fileData: String?
    var pdfData: String?
    var fileName: String?
    var toolCallId: String?
    var toolName: String?
    var toolCalls: [ToolCall]?
    let createdAt: Date
    var deletedAt: Date?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case role
        case content
        case tokenCount = "token_count"
        case finishReason = "finish_reason"
        case imageURL = "image_url"
        case fileData = "file_data"
        case pdfData = "pdf_data"
        case fileName = "file_name"
        case toolCallId = "tool_call_id"
        case toolName = "tool_name"
        case toolCalls = "tool_calls"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
    

    func asDictionary() -> [String: Any] {
        if let imageURL = imageURL {
            return [
                "role": role.rawValue,
                "content": [
                    [
                        "type": "text",
                        "text": content
                    ],
                    [
                        "type": "image_url",
                        "image_url": imageURL
                    ]
                ]
            ]
        }
        
        if let fileData = fileData {
            return [
                "role": role.rawValue,
                "content": [
                    [
                        "type": "text",
                        "text": "This is the content of a file attached by the user: \(fileData)"
                    ],
                    [
                        "type": "text",
                        "text": content
                    ]
                ]
            ]
        }
        
        if let pdfData = pdfData {
            return [
                "role": role.rawValue,
                "content": [
                    [
                        "type": "text",
                        "text": content ?? ""
                    ],
                    [
                        "type": "file",
                        "file": [
                            "filename": fileName ?? "file.pdf",
                            "file_data": pdfData
                        ]
                    ]
                ]
            ]
        }
        
        if let toolCallId = toolCallId,
           let toolName = toolName {
            return [
                "role": "tool",
                "tool_call_id": toolCallId,
                "name": toolName,
                "content": content ?? ""
            ]
        }
        
        if let toolCalls = toolCalls {
            return [
                "role": "assistant",
                "tool_calls": toolCalls.map({ $0.asDictionary() })
            ]
        }
        
        return ["role": role.rawValue, "content": content ?? ""]
        
    }
}
