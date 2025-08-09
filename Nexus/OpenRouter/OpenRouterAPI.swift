//
//  OpenRouterAPI.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation
import SwiftUI
import PhotosUI

@Observable
@MainActor
class OpenRouterAPI {
    
    // Simplified tool call structure
    private struct PendingToolCall {
        var id: String = ""
        var name: String = ""
        var arguments: String = ""
    }
    
    private struct WebSearchArgs: Codable {
        var query: String
    }
    
    static let shared = OpenRouterAPI()
    
    private let API_KEY = ""
    private let completionsURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    
    var selectedFileURL: URL?
    var selectedImage: UIImage? = nil
    var photoPickerItems: PhotosPickerItem? = nil {
        didSet {
            Task {
                await loadImage()
            }
        }
    }
    var output: String = ""
    var chat: [Message] = []
    var selectedModel: OpenRouterModel = DefaultsManager.shared.getModel()
    
    // Main entry point for streaming
    func stream(isWebSearch: Bool = false) async throws {
        // Create assistant placeholder message for UI
        let placeholderMessage = Message(
            chatId: SupabaseManager.shared.currentChat!.id,
            role: .assistant,
            content: "",
            createdAt: Date()
        )
        try await SupabaseManager.shared.addMessageToChat(placeholderMessage)
        
        // Start streaming with the placeholder
        try await performStreaming(placeholderId: placeholderMessage.id)
    }
    
    // Core streaming logic - simplified and cleaner
    private func performStreaming(placeholderId: UUID) async throws {
        // Build request
        let request = try buildRequest(excludingMessageId: placeholderId)
        
        // Start streaming
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("[DEBUG] HTTP Error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            return
        }
        
        // Process SSE stream
        var buffer = ""
        var toolCalls: [Int: PendingToolCall] = [:]  // Index -> ToolCall
        var hasReceivedContent = false
        
        for try await byte in bytes {
            buffer.append(String(bytes: [byte], encoding: .utf8) ?? "")
            
            // Process complete lines
            while let lineRange = buffer.range(of: "\n") {
                let line = String(buffer[..<lineRange.lowerBound])
                buffer.removeSubrange(..<lineRange.upperBound)
                
                // Process SSE line
                if line.hasPrefix("data: ") {
                    let data = String(line.dropFirst(6))
                    
                    if data == "[DONE]" {
                        print("[DEBUG] Stream complete")
                        break
                    }
                    
                    // Parse JSON chunk
                    if let processed = try processChunk(
                        data: data,
                        placeholderId: placeholderId,
                        toolCalls: &toolCalls,
                        hasReceivedContent: &hasReceivedContent
                    ) {
                        // If processChunk returns true, we need to handle tool calls
                        if processed {
                            try await handleToolCalls(Array(toolCalls.values.sorted { $0.id < $1.id }))
                            return
                        }
                    }
                }
            }
        }
    }
    
    // Process a single SSE chunk
    private func processChunk(
        data: String,
        placeholderId: UUID,
        toolCalls: inout [Int: PendingToolCall],
        hasReceivedContent: inout Bool
    ) throws -> Bool? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let choice = choices.first,
              let delta = choice["delta"] as? [String: Any] else {
            return nil
        }
        
        // Handle content streaming
        if let content = delta["content"] as? String, !content.isEmpty {
            hasReceivedContent = true
            appendToMessage(placeholderId: placeholderId, content: content)
        }
        
        // Handle tool call streaming
        if let toolCallDeltas = delta["tool_calls"] as? [[String: Any]] {
            for toolCallDelta in toolCallDeltas {
                let index = toolCallDelta["index"] as? Int ?? 0
                
                // Get or create tool call for this index
                var toolCall = toolCalls[index] ?? PendingToolCall()
                
                // Update tool call properties
                if let id = toolCallDelta["id"] as? String {
                    toolCall.id = id
                }
                
                if let function = toolCallDelta["function"] as? [String: Any] {
                    if let name = function["name"] as? String {
                        toolCall.name = name
                    }
                    if let arguments = function["arguments"] as? String {
                        toolCall.arguments += arguments
                    }
                }
                
                toolCalls[index] = toolCall
            }
        }
        
        // Check finish reason
        if let finishReason = delta["finish_reason"] as? String ?? choice["finish_reason"] as? String {
            print("[DEBUG] Finish reason: \(finishReason)")
            
            switch finishReason {
            case "tool_calls":
                // Return true to signal tool calls need handling
                return true
            case "stop":
                // Normal completion
                return false
            default:
                return nil
            }
        }
        
        return nil
    }
    
    // Handle tool calls execution
    private func handleToolCalls(_ toolCalls: [PendingToolCall]) async throws {
        for toolCall in toolCalls {
            print("[DEBUG] Executing tool: \(toolCall.name) with args: \(toolCall.arguments)")
            
            // 1. Save assistant's tool call message
            let assistantToolMessage = Message(
                chatId: SupabaseManager.shared.currentChat!.id,
                role: .assistant,
                content: nil,
                toolCalls: [ToolCall(
                    id: toolCall.id,
                    type: "function",
                    function: ToolFunction(
                        name: toolCall.name,
                        arguments: toolCall.arguments
                    )
                )],
                createdAt: Date()
            )
            try await SupabaseManager.shared.addMessageToChat(assistantToolMessage)
            
            // 2. Execute the tool
            var toolResult = "Tool execution failed"
            if toolCall.name == "search_web" {
                do {
                    let args = try JSONDecoder().decode(WebSearchArgs.self, from: Data(toolCall.arguments.utf8))
                    toolResult = try await ToolsManager().executeWebSearch(args.query)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    print("[DEBUG] Tool execution error: \(error)")
                    toolResult = "Error executing web search: \(error.localizedDescription)"
                }
            }
            
            // 3. Save tool result message
            let toolResultMessage = Message(
                chatId: SupabaseManager.shared.currentChat!.id,
                role: .tool,
                content: toolResult,
                toolCallId: toolCall.id,
                toolName: toolCall.name,
                createdAt: Date()
            )
            try await SupabaseManager.shared.addMessageToChat(toolResultMessage)
        }
        
        // 4. Continue conversation with tool results
        try await stream(isWebSearch: false)
    }
    
    // Build API request
    private func buildRequest(excludingMessageId: UUID) throws -> URLRequest {
        var request = URLRequest(url: completionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // Get messages excluding the placeholder
        let messages = SupabaseManager.shared.currentMessages
            .filter { $0.id != excludingMessageId }
            .map { $0.asDictionary() }
        
        var payload: [String: Any] = [
            "model": selectedModel.code,
            "messages": messages,
            "stream": true
        ]
        
        // Add tools
        let tools = [ToolsManager().makeWebSearchTool()]
        payload["tools"] = tools
        payload["tool_choice"] = "auto"
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        // Debug print
        if let prettyPrinted = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
           let string = String(data: prettyPrinted, encoding: .utf8) {
            print("[DEBUG] Request payload:\n\(string)")
        }
        
        return request
    }
    
    // Helper to append content to the placeholder message
    private func appendToMessage(placeholderId: UUID, content: String) {
        guard let index = SupabaseManager.shared.currentMessages
            .lastIndex(where: { $0.id == placeholderId }) else { return }
        
        if SupabaseManager.shared.currentMessages[index].content == nil {
            SupabaseManager.shared.currentMessages[index].content = content
        } else {
            SupabaseManager.shared.currentMessages[index].content! += content
        }
    }
    
    // MARK: - Image and File Handling (unchanged)
    
    private func loadImage() async {
        guard let item = photoPickerItems else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            await MainActor.run {
                self.selectedImage = uiImage
            }
        }
    }
    
    public func base64FromSwiftUIImage() -> String? {
        guard let image = selectedImage else { return nil }
        guard let imageData = image.pngData() else { return nil }
        return "data:image/jpeg;base64,\(imageData.base64EncodedString())"
    }
    
    public func fileContent() -> String? {
        guard let fileURL = selectedFileURL else { return nil }
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    public func base64FromFileURL() -> String? {
        guard let fileURL = selectedFileURL else { return nil }
        
        let fileExtension = fileURL.pathExtension
        let dataURI = dataURIPrefix(for: fileExtension)
        
        do {
            let encodedFile = try Data(contentsOf: fileURL).base64EncodedString()
            return "\(dataURI)\(encodedFile)"
        } catch {
            print("[DEBUG] Error encoding file: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func dataURIPrefix(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "pdf": return "data:application/pdf;base64,"
        case "txt": return "data:text/plain;base64,"
        case "csv": return "data:text/csv;base64,"
        case "json": return "data:application/json;base64,"
        case "xml": return "data:application/xml;base64,"
        case "html", "htm": return "data:text/html;base64,"
        case "md": return "data:text/markdown;base64,"
        case "rtf": return "data:application/rtf;base64,"
        case "yaml", "yml": return "data:text/yaml;base64,"
        default: return "data:application/octet-stream;base64,"
        }
    }
    
    public func generateChatTitle(from query: String) async throws -> String? {
        let url = URL(string: "https://openrouter.ai/api/v1/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
            Given the user prompt, generate a short, concise yet effective title for a chat. \
            RESPOND ONLY WITH THE TITLE. \
            QUERY: \(query.trimmingCharacters(in: .whitespacesAndNewlines))
            """
        
        let payload: [String: Any] = [
            "model": "google/gemini-2.5-flash-lite",
            "prompt": prompt
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("[DEBUG] Failed to generate chat title: Invalid response")
            return nil
        }
        
        let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
        return decoded.choices.first?.text
    }
}
