//
//  OpenRouterViewModel.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 19/08/25.
//

import Foundation
import SwiftUI

@MainActor
@Observable
class OpenRouterViewModel {
    
    static let shared = OpenRouterViewModel()
    
    private let streamer = OpenRouterStreamClient(config: .init(apiKeyProvider: {
        Keychain.load(Keychain.OPENROUTER_USER_KEY)
    }))
    
    private struct WebSearchArgs: Codable { let query: String }
    private struct DocLookupArgs: Codable { let docID: String }
    private struct CrawlToolArgs: Codable { let urls: [String] }
    
    private let selectedModel: OpenRouterModel = DefaultsManager.shared.getModel()
    
    public func stream() async throws {
        guard let currentChat = SupabaseManager.shared.currentChat else { return }
        
        let userLocation = SupabaseManager.shared.profile?.country
        let systemMessage = SystemPrompts.shared.getSystemMessage(currentChat.id, userLocation: userLocation ?? "")
        SupabaseManager.shared.currentMessages.insert(systemMessage, at: 0)
        
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
                },
                onStateChange: { state in
                    // optional observability
                    switch state {
                    case .idle:
                        debugPrint("[DEBUG] Change state: \(state)")
                    case .streaming:
                        debugPrint("[DEBUG] Change state: \(state)")
                    case .finished(reason: let reason):
                        debugPrint("[DEBUG] Change state: \(state). Reason: \(reason ?? "")")
                    case .cancelled:
                        debugPrint("[DEBUG] Change state: \(state)")
                        self.streamer.resume(strategy: .retrySamePrompt, originalBody: body)
                    case .failed(message: let message):
                        debugPrint("[DEBUG] Change state: \(state). Error: \(message.debugDescription)")
                    }
                }
            )
        )
    }
    
    private func onFinishForToolCalls(placeholderId: UUID, order: [Int], toolsByIndex: [Int: ToolCallFragment]) async throws {
        var newPlaceholderId = placeholderId
        
        if let message = SupabaseManager.shared.currentMessages.first(where: { $0.id == placeholderId }),
           let _ = message.content {
            SupabaseManager.shared.updateLastMessage()
            
            let newToolCallMessage = Message(
                chatId: SupabaseManager.shared.currentChat!.id,
                role: .tool,
                createdAt: Date()
            )
            SupabaseManager.shared.currentMessages.append(newToolCallMessage)
            newPlaceholderId = newToolCallMessage.id
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
            // Preserve any partial content that was streamed before tool calls
            // and simply attach the toolCalls to the same assistant message.
            SupabaseManager.shared.currentMessages[idx].toolCalls = toolCalls
        }
        
        // 2) Execute tools (in parallel) and store each tool result message.
        try await withThrowingTaskGroup(of: Message.self) { group in
            for call in toolCalls {
                group.addTask {
                    let resultContent: String
                    var toolMsg: Message = Message(
                        chatId: currentChat.id,
                        role: .tool,
                        createdAt: Date()
                    )
                    
                    if call.function?.name == "search_web" {
                        // Execute your web search tool
                        do {
                            let args = try JSONDecoder().decode(WebSearchArgs.self, from: Data((call.function?.arguments ?? "").utf8))
                            let lastUserMessage = await SupabaseManager.shared.currentMessages.last(where: { $0.role == .user })!.content
                                
                            toolMsg.toolCallId = call.id
                            toolMsg.toolName = call.function?.name
                            toolMsg.toolArgs = "Searching for \"\(args.query)\""
                            
                            resultContent = try await ToolsManager().executeTool(named: "search_web", arguments: args.query, other: lastUserMessage)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            toolMsg.content = resultContent
                        } catch {
                            resultContent = "Error executing web search: \(error.localizedDescription)"
                        }
                    } else if call.function?.name == "doc_lookup"  {
                        // Execute doc lookup tool
                        toolMsg.toolCallId = call.id
                        toolMsg.toolName = call.function?.name
                        
                        do {
                            let args = try JSONDecoder().decode(DocLookupArgs.self, from: Data((call.function?.arguments ?? "").utf8))
                            let lastUserMessage = await SupabaseManager.shared.currentMessages.last(where: { $0.role == .user })!.content
                            resultContent = try await ToolsManager().executeTool(named: "doc_lookup", arguments: args.docID, other: lastUserMessage)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            toolMsg.content = resultContent
                        } catch {
                            resultContent = "Error executing doc lookup: \(error.localizedDescription)"
                        }
                    } else if call.function?.name == "manage_calendar" {
                        // Execute calendar tool
                        toolMsg.toolCallId = call.id
                        toolMsg.toolName = call.function?.name
                        
                        do {
                            // Pass the arguments directly as they contain all needed info
                            resultContent = try await ToolsManager().executeTool(
                                named: "manage_calendar",
                                arguments: call.function?.arguments ?? "{}"
                            ).trimmingCharacters(in: .whitespacesAndNewlines)
                            toolMsg.content = resultContent
                        } catch {
                            resultContent = "Error executing calendar operation: \(error.localizedDescription)"
                        }
                    } else if call.function?.name == "get_webpage_info" {
                        toolMsg.toolCallId = call.id
                        toolMsg.toolName = call.function?.name
                        
                        do {
                            let args = try JSONDecoder().decode(CrawlToolArgs.self, from: Data((call.function?.arguments ?? "").utf8))
                            resultContent = try await ToolsManager().executeTool(named: "get_webpage_info", arguments: args.urls.joined(separator: ";"))
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            toolMsg.content = resultContent
                        } catch {
                            resultContent = "Error executing crawl webpage: \(error.localizedDescription)"
                        }
                    } else {
                        resultContent = #"{"error":"No handler for tool: \#(call.function?.name ?? "unknown")"}"#
                    }
                    
                    try await SupabaseManager.shared.addMessageToChat(toolMsg)
                    return toolMsg
                }
            }
            
            // Drain the group to ensure all tool messages are saved before continuing.
            for try await _ in group { /* no-op */ }
        }
        
        // 3) Continue the conversation: start a fresh streamed request.
        try await stream()
    }

    
    private func buildPayload(excludingMessageId: UUID) -> [String: Any] {
        let messagesPayload = SupabaseManager.shared.currentMessages
            .filter { $0.id != excludingMessageId }
            .filter { !($0.role == .assistant && ($0.content?.isEmpty ?? true) && $0.toolCalls == nil) }
            .map { $0.asDictionary() }
        
        
        var payload: [String: Any] = [
            "model": selectedModel.code,
            "messages": messagesPayload,
            "stream": true,
            "reasoning": [
                "effort": DefaultsManager.shared.getReasoningEffort(),
                "exclude": false,
                "enabled": DefaultsManager.shared.getReasoningEnabled()
            ],
            "usage": [
                "include": true
            ]
        ]
        
        // Tools
        let tools = ToolsManager().getAllToolDefinitions()
        payload["tools"] = tools
        payload["tool_choice"] = "auto"
        
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
}

