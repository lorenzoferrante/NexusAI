//
//  Message.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation

enum Role: String, Codable {
    case system
    case user
    case assistant
    case tool
    case error
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

public struct ImageStruct: Decodable, Equatable, Hashable {
    struct ImageURL: Decodable, Hashable { let url: String }
    let type: String
    let imageURL: ImageURL
    private enum CodingKeys: String, CodingKey {
        case type
        case imageURL = "image_url"
    }
    
    public static func == (lhs: ImageStruct, rhs: ImageStruct) -> Bool {
        return lhs.imageURL.url == rhs.imageURL.url
    }
}

struct Message: Codable, Identifiable, Hashable {
    var id = UUID()
    let chatId: UUID
    let role: Role
    var content: String?
    var reasoning: String?
    var tokenCount: Int?
    var finishReason: String?
    var imageURL: String?
    var fileData: String?
    var pdfData: String?
    var fileName: String?
    var toolCallId: String?
    var toolName: String?
    var toolCalls: [ToolCall]?
    var toolArgs: String?
    let createdAt: Date
    var deletedAt: Date?
    var modelName: String?
    var images: [ImageStruct]?
    
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
        case toolArgs = "tool_args"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
        case modelName = "model_name"
    }
    

    func asDictionary() -> [String: Any] {
        if role == .error {
            return [:]
        }
        
        if role == .system {
            return [
                "role": role.rawValue,
                "content": [
                    [
                        "type": "text",
                        "text": content ?? "",
                        "cache_control": [
                            "type": "ephemeral"
                        ]
                    ]
                ]
            ]
        }
        
        let outboundImages = imageURLList
        if !outboundImages.isEmpty {
            var contentParts: [[String: Any]] = []
            if let content, !content.isEmpty {
                contentParts.append([
                    "type": "text",
                    "text": content
                ])
            }

            for url in outboundImages {
                contentParts.append([
                    "type": "image_url",
                    "image_url": ["url": url]
                ])
            }

            return [
                "role": role.rawValue,
                "content": contentParts
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
        
        // Tool result message to send back to the model.
        if let toolCallId = toolCallId,
           let toolName = toolName {
            return [
                "role": "tool",
                "tool_call_id": toolCallId,
                "name": toolName,
                "content": content ?? ""
            ]
        }
        
        // Assistant message that initiated tool calls.
        // Include BOTH content (if any) and tool_calls, as allowed by OpenAI/OpenRouter.
        if let toolCalls = toolCalls {
            var dict: [String: Any] = [
                "role": "assistant",
                "tool_calls": toolCalls.map({ $0.asDictionary() })
            ]
            // Keep any assistant text that preceded the tool call.
            if let content, !content.isEmpty {
                dict["content"] = content
            } else {
                // Some providers require a string; empty is acceptable.
                dict["content"] = ""
            }
            return dict
        }
        
        return ["role": role.rawValue, "content": content ?? ""]
        
    }
}

extension Message {
    /// Returns true when the message carries a PDF attachment that should be parsed by the model.
    var containsPDF: Bool {
        if let data = pdfData, !data.isEmpty {
            return true
        }
        if let fileData, fileData.lowercased().hasPrefix("data:application/pdf") {
            return true
        }
        if let name = fileName?.lowercased(), name.hasSuffix(".pdf") {
            return true
        }
        return false
    }

    var imageURLList: [String] {
        guard let imageURL, !imageURL.isEmpty else { return [] }
        if let data = imageURL.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        if imageURL.contains("||") {
            return imageURL
                .split(separator: "|", omittingEmptySubsequences: true)
                .map { String($0) }
        }
        return [imageURL]
    }

}
