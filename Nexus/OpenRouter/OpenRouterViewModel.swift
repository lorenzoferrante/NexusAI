//
//  OpenRouterViewModel.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 19/08/25.
//

import Foundation
import SwiftUI
import UIKit
import Auth

@MainActor
@Observable
class OpenRouterViewModel {
    
    static let shared = OpenRouterViewModel()
    
    // Indicates whether a stream is currently active.
    // Used by the UI to toggle the send/stop icon.
    var isStreaming: Bool = false
    
    let streamer = OpenRouterStreamClient(config: {
        var c = OpenRouterStreamClient.Config(apiKeyProvider: { Keychain.load(Keychain.OPENROUTER_USER_KEY) })
        c.autoResumeOnForeground = true
        c.continuationBuilder = { originalBody in
            guard var bMsgs = originalBody["messages"] as? [[String: Any]] else {
                return nil
            }
            bMsgs.append(["role": "user", "content": "Continue."])
            return bMsgs
        }
        return c
    }())
    
    private struct WebSearchArgs: Codable { let query: String }
    private struct DocLookupArgs: Codable { let docID: String }
    private struct CrawlToolArgs: Codable { let urls: [String] }
    
    public var selectedModel: OpenRouterModelRow = DefaultsManager.shared.getModel()
    
    public func stream() async throws {
        guard let currentChat = SupabaseManager.shared.currentChat else { return }
        
        let userLocation = SupabaseManager.shared.profile?.country
        if SupabaseManager.shared.currentMessages.filter({ $0.role == .system }).isEmpty {
            let systemMessage = SystemPrompts.shared.getSystemMessage(currentChat.id, userLocation: userLocation ?? "")
            SupabaseManager.shared.currentMessages.insert(systemMessage, at: 0)
        }
        
        let placeholder = Message(
            chatId: currentChat.id,
            role: .assistant,
            content: "",
            createdAt: Date(),
        )
        try await SupabaseManager.shared.addMessageToChat(placeholder)
        
        let body = buildPayload(excludingMessageId: placeholder.id)
        
        var toolsByIndex: [Int: ToolCallFragment] = [:]
        var order: [Int] = []
        
        streamer.startStreaming(
            body: body,
            handlers: .init(
                onToken: { token in
                    // append to your partial message
                    debugPrint("[DEBUG] Token: \(token)")
                    self.appendToMessage(placeholderId: placeholder.id, content: token)
                },
                onReasoningToken: { reasoning in
                    // append to your partial message
                    debugPrint("[DEBUG] Reasoning Token: \(reasoning)")
                    self.appendReasoningToMessage(placeholderId: placeholder.id, reasoning: reasoning)
                },
                onImageDelta: { images in
                    
                },
                onToolCallDelta: { fragment in
                    // accumulate tool_calls by fragment.index
                    debugPrint("[DEBUG] Fragment: \(fragment)")
                    if !order.contains(fragment.index) {
                        order.append(fragment.index)
                    }
                    toolsByIndex[fragment.index] = fragment
                },
                onFinish: { finish in
                    // finalize the message; finish could be "stop" | "tool_calls" | ...
                    debugPrint("[DEBUG] Finish: \(finish ?? "")")
                    
                    switch finish ?? "" {
                    case "tool_calls":
                        Task {
                            try await self.onFinishForToolCalls(
                                placeholderId: placeholder.id,
                                order: order,
                                toolsByIndex: toolsByIndex
                            )
                        }
                    case "stop":
                        SupabaseManager.shared.updateLastMessage()
                    default:
                        break
                    }
                },
                onError: { message in
                    // show error and allow retry
                    debugPrint("[DEBUG] Error: \(message.debugDescription)")
                    
                    let chatId = currentChat.id
                    let errorMessage = Message(
                        chatId: chatId,
                        role: .error,
                        content: message.debugDescription,
                        createdAt: Date()
                    )
                    Task {
                        try await SupabaseManager.shared.addMessageToChat(errorMessage)
                    }
                },
                onStateChange: { state in
                    // optional observability + drive UI state
                    switch state {
                    case .idle:
                        debugPrint("[DEBUG] Change state: \(state)")
                        self.isStreaming = false
                    case .streaming:
                        debugPrint("[DEBUG] Change state: \(state)")
                        self.isStreaming = true
                    case .finished(reason: let reason):
                        debugPrint("[DEBUG] Change state: \(state). Reason: \(reason ?? "")")
                        self.isStreaming = false
                    case .cancelled:
                        debugPrint("[DEBUG] Change state: \(state)")
                        self.isStreaming = false
                        self.streamer.appDidBecomeActive()
                    case .failed(message: let message):
                        debugPrint("[DEBUG] Change state: \(state). Error: \(message.debugDescription)")
                        self.isStreaming = false
                    }
                }
            )
        )
    }
    
    private func onFinishForToolCalls(placeholderId: UUID, order: [Int], toolsByIndex: [Int: ToolCallFragment]) async throws {
        var newPlaceholderId = placeholderId
        
        if let message = SupabaseManager.shared.currentMessages.first(where: { $0.id == placeholderId }),
           let _ = message.content {
            // Persist the streamed assistant content first
            SupabaseManager.shared.updateLastMessage()
            
            // Create a fresh assistant message that will hold the tool_calls
            let newAssistantToolCallMessage = Message(
                chatId: SupabaseManager.shared.currentChat!.id,
                role: .assistant,
                content: nil,
                createdAt: Date()
            )
            // Persist so it's available after app relaunch
            try await SupabaseManager.shared.addMessageToChat(newAssistantToolCallMessage)
            newPlaceholderId = newAssistantToolCallMessage.id
        }
        
        // Finalize tool calls, persist assistant-with-tool_calls, execute tools, and RECURSE.
        let toolCalls = finalizedToolCalls(order: order, toolsByIndex: toolsByIndex)
        try await handleToolCalls(toolCalls, placeholderId: newPlaceholderId)
    }
    
    private func finalizedToolCalls(order: [Int], toolsByIndex: [Int: ToolCallFragment]) -> [ToolCall] {
        order.compactMap { idx -> ToolCall? in
            guard let b = toolsByIndex[idx],
                  let id = b.id,
                  let name = b.name
            else { return nil }
            return ToolCall(
                id: id,
                type: "function",
                function: ToolFunction(name: name, arguments: b.argumentsJSON)
            )
        }
    }
    
    private func handleToolCalls(_ toolCalls: [ToolCall], placeholderId: UUID) async throws {
        guard let currentChat = SupabaseManager.shared.currentChat else { return }
        
        // Update the placeholder message with the ID we already have
        if let idx = SupabaseManager.shared.currentMessages.firstIndex(where: { $0.id == placeholderId }) {
            // Attach toolCalls to the assistant message in memory and persist to DB
            SupabaseManager.shared.currentMessages[idx].toolCalls = toolCalls
            try await SupabaseManager.shared.updateMessageToolCalls(messageId: placeholderId, toolCalls: toolCalls)
        }
        
        // 2) Execute tools (in parallel). Insert a placeholder tool message first, then update it with results.
        try await withThrowingTaskGroup(of: Message.self) { group in
            for call in toolCalls {
                group.addTask {
                    var resultContent: String = ""
                    var toolMsg: Message = Message(
                        chatId: currentChat.id,
                        role: .tool,
                        createdAt: Date()
                    )

                    // Common fields
                    toolMsg.toolCallId = call.id
                    toolMsg.toolName = call.function?.name

                    // Provide a friendly args label where possible so the UI can render immediately.
                    if call.function?.name == "search_web" {
                        // Execute your web search tool
                        do {
                            let args = try JSONDecoder().decode(WebSearchArgs.self, from: Data((call.function?.arguments ?? "").utf8))
                            let lastUserMessage = await SupabaseManager.shared.currentMessages.last(where: { $0.role == .user })!.content
                            toolMsg.toolArgs = "Searching for \"\(args.query)\""
                            // Insert the tool message BEFORE execution
                            try await SupabaseManager.shared.addMessageToChat(toolMsg)

                            resultContent = try await ToolsManager().executeTool(named: "search_web", arguments: args.query, other: lastUserMessage)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            toolMsg.content = await self.displayContentForTool(name: call.function?.name, fullContent: resultContent)
                            try await SupabaseManager.shared.updateToolMessage(toolMsg)
                        } catch {
                            resultContent = "Error executing web search: \(error.localizedDescription)"
                            toolMsg.content = resultContent
                            // Ensure message is present even on error
                            if await SupabaseManager.shared.currentMessages.firstIndex(where: { $0.id == toolMsg.id }) == nil {
                                try? await SupabaseManager.shared.addMessageToChat(toolMsg)
                            }
                            try? await SupabaseManager.shared.updateToolMessage(toolMsg)
                        }
                    } else if call.function?.name == "doc_lookup"  {
                        // Execute doc lookup tool
                        do {
                            let args = try JSONDecoder().decode(DocLookupArgs.self, from: Data((call.function?.arguments ?? "").utf8))
                            let lastUserMessage = await SupabaseManager.shared.currentMessages.last(where: { $0.role == .user })!.content
                            try await SupabaseManager.shared.addMessageToChat(toolMsg)
                            resultContent = try await ToolsManager().executeTool(named: "doc_lookup", arguments: args.docID, other: lastUserMessage)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            toolMsg.content = await self.displayContentForTool(name: call.function?.name, fullContent: resultContent)
                            try await SupabaseManager.shared.updateToolMessage(toolMsg)
                        } catch {
                            resultContent = "Error executing doc lookup: \(error.localizedDescription)"
                            toolMsg.content = resultContent
                            if await SupabaseManager.shared.currentMessages.firstIndex(where: { $0.id == toolMsg.id }) == nil {
                                try? await SupabaseManager.shared.addMessageToChat(toolMsg)
                            }
                            try? await SupabaseManager.shared.updateToolMessage(toolMsg)
                        }
                    } else if call.function?.name == "manage_calendar" {
                        // Execute calendar tool
                        do {
                            try await SupabaseManager.shared.addMessageToChat(toolMsg)
                            // Pass the arguments directly as they contain all needed info
                            resultContent = try await ToolsManager().executeTool(
                                named: "manage_calendar",
                                arguments: call.function?.arguments ?? "{}"
                            ).trimmingCharacters(in: .whitespacesAndNewlines)
                            toolMsg.content = await self.displayContentForTool(name: call.function?.name, fullContent: resultContent)
                            try await SupabaseManager.shared.updateToolMessage(toolMsg)
                        } catch {
                            resultContent = "Error executing calendar operation: \(error.localizedDescription)"
                            toolMsg.content = resultContent
                            if await SupabaseManager.shared.currentMessages.firstIndex(where: { $0.id == toolMsg.id }) == nil {
                                try? await SupabaseManager.shared.addMessageToChat(toolMsg)
                            }
                            try? await SupabaseManager.shared.updateToolMessage(toolMsg)
                        }
                    } else if call.function?.name == "get_webpage_info" {
                        do {
                            try await SupabaseManager.shared.addMessageToChat(toolMsg)
                            let args = try JSONDecoder().decode(CrawlToolArgs.self, from: Data((call.function?.arguments ?? "").utf8))
                            resultContent = try await ToolsManager().executeTool(named: "get_webpage_info", arguments: args.urls.joined(separator: ";"))
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            toolMsg.content = await self.displayContentForTool(name: call.function?.name, fullContent: resultContent)
                            try await SupabaseManager.shared.updateToolMessage(toolMsg)
                        } catch {
                            resultContent = "Error executing crawl webpage: \(error.localizedDescription)"
                            toolMsg.content = resultContent
                            if await SupabaseManager.shared.currentMessages.firstIndex(where: { $0.id == toolMsg.id }) == nil {
                                try? await SupabaseManager.shared.addMessageToChat(toolMsg)
                            }
                            try? await SupabaseManager.shared.updateToolMessage(toolMsg)
                        }
                    } else if call.function?.name == "create_text_file" {
                        // Decode to show a friendly args label with the file name
                        struct CreateTextFileArgs: Codable { let fileName: String; let content: String }
                        if let data = (call.function?.arguments ?? "{}").data(using: .utf8),
                           let decoded = try? JSONDecoder().decode(CreateTextFileArgs.self, from: data) {
                            toolMsg.toolArgs = "Creating file \"\(decoded.fileName)\""
                        }
                        do {
                            try await SupabaseManager.shared.addMessageToChat(toolMsg)
                            resultContent = try await ToolsManager().executeTool(
                                named: "create_text_file",
                                arguments: call.function?.arguments ?? "{}"
                            ).trimmingCharacters(in: .whitespacesAndNewlines)
                            toolMsg.content = await self.displayContentForTool(name: call.function?.name, fullContent: resultContent)
                            try await SupabaseManager.shared.updateToolMessage(toolMsg)
                        } catch {
                            resultContent = "Error creating text file: \(error.localizedDescription)"
                            toolMsg.content = resultContent
                            if await SupabaseManager.shared.currentMessages.firstIndex(where: { $0.id == toolMsg.id }) == nil {
                                try? await SupabaseManager.shared.addMessageToChat(toolMsg)
                            }
                            try? await SupabaseManager.shared.updateToolMessage(toolMsg)
                        }
                    } else if call.function?.name == "generate_image" {
                        // Execute image generation tool
                        struct ImageArgs: Codable { let prompt: String? }
                        var promptPreview: String = ""
                        if let data = (call.function?.arguments ?? "{}").data(using: .utf8),
                           let decoded = try? JSONDecoder().decode(ImageArgs.self, from: data) {
                            if let p = decoded.prompt { promptPreview = p }
                        }
                        if !promptPreview.isEmpty {
                            let clipped = promptPreview.count > 40 ? String(promptPreview.prefix(40)) + "…" : promptPreview
                            toolMsg.toolArgs = "Generating image for \"\(clipped)\""
                        } else {
                            toolMsg.toolArgs = "Generating image"
                        }

                        do {
                            try await SupabaseManager.shared.addMessageToChat(toolMsg)

                            // Gather last user image attachments, if any
                            let lastUser = await SupabaseManager.shared.currentMessages.last(where: { $0.role == .user })
                            let images = lastUser?.imageURLList ?? []
                            let otherPayload: [String: Any] = ["image_urls": images]
                            let otherData = (try? JSONSerialization.data(withJSONObject: otherPayload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

                            // Call the tool
                            let raw = try await ToolsManager().executeTool(
                                named: "generate_image",
                                arguments: call.function?.arguments ?? "{}",
                                other: otherData
                            ).trimmingCharacters(in: .whitespacesAndNewlines)

                            // Parse { content: String, images: [String] }
                            struct ResultEnvelope: Decodable { let content: String?; let images: [String]? }
                            var contentOut = ""
                            var outImages: [ImageStruct] = []
                            if let rdata = raw.data(using: .utf8), let env = try? JSONDecoder().decode(ResultEnvelope.self, from: rdata) {
                                // Do NOT display text output for image generation; ignore any caption.
                                contentOut = ""
                                if let imgs = env.images {
                                    outImages = imgs.map { b64 in
                                        ImageStruct(type: "image_url", imageURL: .init(url: b64))
                                    }
                                    // Persist the first generated image to Supabase for durability across sessions
                                    if let first = imgs.first,
                                       let ui = Base64ImageUtils.uiImage(fromDataURL: first),
                                       let data = ui.jpegData(compressionQuality: 0.92) {
                                        let userID = await SupabaseManager.shared.getUser()?.id.uuidString ?? "uploads"
                                        let remoteName = "\(userID)/\(UUID().uuidString).jpeg"
                                        await SupabaseManager.shared.uploadImageToBucket(data, fileName: remoteName)
                                        let remoteURL = await SupabaseManager.shared.retrieveImageURLFor(remoteName)
                                        // Save the remote URL on the tool message so it’s persisted in DB
                                        try? await SupabaseManager.shared.updateMessageImageURL(toolMsg.id, imageURL: remoteURL)
                                    }
                                }
                            } else {
                                // On parse fallback, keep content empty as well.
                                contentOut = ""
                            }

                            // Update UI/DB
                            toolMsg.content = await self.displayContentForTool(name: call.function?.name, fullContent: contentOut)
                            try await SupabaseManager.shared.updateToolMessage(toolMsg)
                            if !outImages.isEmpty {
                                await MainActor.run {
                                    if let idx = SupabaseManager.shared.currentMessages.firstIndex(where: { $0.id == toolMsg.id }) {
                                        SupabaseManager.shared.currentMessages[idx].images = outImages
                                    }
                                }
                            }
                        } catch {
                            resultContent = "Error generating image: \(error.localizedDescription)"
                            toolMsg.content = resultContent
                            if await SupabaseManager.shared.currentMessages.firstIndex(where: { $0.id == toolMsg.id }) == nil {
                                try? await SupabaseManager.shared.addMessageToChat(toolMsg)
                            }
                            try? await SupabaseManager.shared.updateToolMessage(toolMsg)
                        }
                    } else {
                        resultContent = #"{"error":"No handler for tool: \#(call.function?.name ?? "unknown")"}"#
                        toolMsg.content = resultContent
                        // Insert then update so the UI shows the tool tile immediately
                        try? await SupabaseManager.shared.addMessageToChat(toolMsg)
                        try? await SupabaseManager.shared.updateToolMessage(toolMsg)
                    }
                    return toolMsg
                }
            }
            
            // Drain the group to ensure all tool messages are saved before continuing.
            for try await _ in group { /* no-op */ }
        }
        
        // 3) Continue the conversation: start a fresh streamed request.
        try await stream()
    }

    // MARK: - Display helpers
    /// For UI display of tool results. In particular, avoid dumping full file content for text file tool.
    private func displayContentForTool(name: String?, fullContent: String) -> String {
        guard let name = name else { return fullContent }
        if name == "create_text_file" {
            // Keep only the header and link; drop any code block preview to avoid large content in chat.
            if let fenceRange = fullContent.range(of: "```") {
                return String(fullContent[..<fenceRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return fullContent
    }

    
    public func buildPayload(excludingMessageId: UUID) -> [String: Any] {
        // 1) Base filter: drop the current streaming placeholder and empty assistant placeholders
        let base = SupabaseManager.shared.currentMessages
            .filter { $0.id != excludingMessageId }
            .filter { !($0.role == .assistant && ($0.content?.isEmpty ?? true) && $0.toolCalls == nil) }

        // 2) Sanitize: remove orphan tool outputs that don't have a preceding assistant tool_calls
        var pendingToolIds = Set<String>()
        var sanitized: [Message] = []
        for m in base {
            if let tcs = m.toolCalls, !tcs.isEmpty {
                pendingToolIds = Set(tcs.compactMap { $0.id })
                sanitized.append(m)
            } else if m.role == .tool {
                if let id = m.toolCallId, pendingToolIds.contains(id) {
                    sanitized.append(m)
                } else {
                    // Drop orphan tool result
                    continue
                }
            } else {
                // Any normal message clears pending context
                pendingToolIds.removeAll()
                sanitized.append(m)
            }
        }

        // Extra safety: drop malformed tool results lacking name/id to avoid provider errors
        let finalizedMessages: [Message] = sanitized.filter { m in
            if m.role == .tool {
                if let name = m.toolName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let _ = m.toolCallId {
                    return true
                }
                // Skip invalid tool messages
                return false
            }
            return true
        }

        let messagesPayload = finalizedMessages.map { $0.asDictionary() }
        let hasPDF = sanitized.contains { $0.containsPDF }
        
        
        var payload: [String: Any] = [
            "model": selectedModel.code,
            "messages": messagesPayload,
            "stream": true,
            "usage": [
                "include": true
            ]
        ]
        
        // Tools
        if (selectedModel.toolUse ?? false) {
            let tools = ToolsManager().getAllToolDefinitions()
            payload["tools"] = tools
            payload["tool_choice"] = "auto"
        }
        
        if (selectedModel.reasoning ?? false) {
            payload["reasoning"] = [
                "effort": DefaultsManager.shared.getReasoningEffort(),
                "exclude": false,
                "enabled": DefaultsManager.shared.getReasoningEnabled()
            ]
        }
        
        // Output Modalities
        payload["modalities"] = selectedModel.outputModalities!.split(separator: ",")

        if hasPDF {
            let defaultPDFPlugin: [String: Any] = [
                "id": "file-parser",
                "pdf": ["engine": "pdf-text"]
            ]
            var plugins = (payload["plugins"] as? [[String: Any]]) ?? []
            let alreadyContainsFileParser = plugins.contains { plugin in
                (plugin["id"] as? String)?.lowercased() == "file-parser"
            }
            if alreadyContainsFileParser {
                payload["plugins"] = plugins.map { plugin in
                    guard let id = (plugin["id"] as? String)?.lowercased(), id == "file-parser" else {
                        return plugin
                    }
                    var updated = plugin
                    var pdfConfig = (plugin["pdf"] as? [String: Any]) ?? [:]
                    if pdfConfig["engine"] == nil {
                        pdfConfig["engine"] = "pdf-text"
                    }
                    updated["pdf"] = pdfConfig
                    return updated
                }
            } else {
                plugins.append(defaultPDFPlugin)
                payload["plugins"] = plugins
            }
        }
        
        return payload
    }
    
    private func appendToMessage(placeholderId: UUID, content: String) {
        guard let idx = SupabaseManager.shared.currentMessages.lastIndex(where: { $0.id == placeholderId }) else { return }
        if SupabaseManager.shared.currentMessages[idx].content == nil {
            SupabaseManager.shared.currentMessages[idx].content = content
        } else {
            SupabaseManager.shared.currentMessages[idx].content! += content
        }
    }
    
    private func appendReasoningToMessage(placeholderId: UUID, reasoning: String) {
        guard let idx = SupabaseManager.shared.currentMessages.lastIndex(where: { $0.id == placeholderId }) else { return }
        if SupabaseManager.shared.currentMessages[idx].reasoning == nil {
            SupabaseManager.shared.currentMessages[idx].reasoning = reasoning
        } else {
            SupabaseManager.shared.currentMessages[idx].reasoning! += reasoning
        }
    }
    
    private func appendImageToMessage(placeholderId: UUID, images: [ImageStruct]) {
        guard let idx = SupabaseManager.shared.currentMessages.lastIndex(where: { $0.id == placeholderId }) else { return }
        SupabaseManager.shared.currentMessages[idx].images = images
    }
}
