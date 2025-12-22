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

public struct ReasoningDetail: Codable, Hashable {
    var id: String?
    var type: String?
    var format: String?
    var index: Int?
    var data: String?
    var summary: String?
    var text: String?
    var signature: String?
    
    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let id { dict["id"] = id }
        if let type { dict["type"] = type }
        if let format { dict["format"] = format }
        if let index { dict["index"] = index }
        if let data { dict["data"] = data }
        if let summary { dict["summary"] = summary }
        if let text { dict["text"] = text }
        if let signature { dict["signature"] = signature }
        return dict
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
    var reasoningDetails: [ReasoningDetail]?
    
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
        case reasoningDetails = "reasoning_details"
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
        
        // Tool result message to send back to the model MUST take precedence over any media attachments.
        if role == .tool,
           let toolCallId = toolCallId,
           let toolName = toolName {
            var dict: [String: Any] = [
                "role": "tool",
                "tool_call_id": toolCallId,
                "name": toolName,
                "content": content ?? ""
            ]
            if let reasoningDetails, !reasoningDetails.isEmpty {
                dict["reasoning_details"] = reasoningDetails.map { $0.asDictionary() }
            }
            return dict
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
            if let reasoningDetails, !reasoningDetails.isEmpty {
                dict["reasoning_details"] = reasoningDetails.map { $0.asDictionary() }
            }
            return dict
        }
        
        var dict: [String: Any] = ["role": role.rawValue, "content": content ?? ""]
        if let reasoningDetails, !reasoningDetails.isEmpty {
            dict["reasoning_details"] = reasoningDetails.map { $0.asDictionary() }
        }
        return dict
        
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
