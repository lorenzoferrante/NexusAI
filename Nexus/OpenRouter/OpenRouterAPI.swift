//
//  OpenRouterAPI.swift (refactored for clarity)
//  Nexus
//
//  Created by ChatGPT on 2025-08-10.
//
//  Goals:
//  - Make streaming + tool-calls very clear and debuggable.
//  - Keep compatibility with your existing `Message` model and Supabase/Tools managers.
//  - Properly accumulate streamed tool_calls and send them as ONE assistant message.
//  - Send tool results as `role:"tool"` messages with the correct `tool_call_id` and `name`.
//  - Loop cleanly to continue the conversation after tools.
//
//  Notes:
//  - This class is @MainActor and @Observable like your original.
//  - We keep `Message.asDictionary()` to preserve your content (text/image/file/tool) shaping.
//  - SSE parsing uses `URLSession.AsyncBytes.lines` for simple, line-by-line handling.
//

import Foundation
import SwiftUI
import PhotosUI

@Observable
@MainActor
class OpenRouterAPI {
    
    // MARK: - Types
    
    /// Internal builder to accumulate streamed tool call fragments.
    private struct PendingToolCall {
        var id: String?
        var name: String?
        var arguments: String = ""  // concatenated JSON string fragments
    }
    
    private struct WebSearchArgs: Codable { let query: String }
    private struct DocLookupArgs: Codable { let docID: String }
    
    // Server-Sent Events (SSE) decoded structure (kept tiny).
    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                struct ToolCallDelta: Decodable {
                    struct FunctionDelta: Decodable {
                        let name: String?
                        let arguments: String?
                    }
                    let index: Int?
                    let id: String?
                    let type: String?
                    let function: FunctionDelta?
                }
                let content: String?
                let toolCalls: [ToolCallDelta]?
            }
            let delta: Delta
            let finishReason: String?
        }
        let choices: [Choice]
        struct Usage: Decodable {
            let promptTokens: Int?
            let completionTokens: Int?
            let totalTokens: Int?
        }
        let usage: Usage?
    }
    
    // MARK: - Config
    
    static let shared = OpenRouterAPI()
    
    private let API_KEY = ""
    private let completionsURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    
    // MARK: - Bindings/State you already had
    
    var selectedFileURL: URL?
    var selectedImage: UIImage? = nil
    var photoPickerItems: PhotosPickerItem? = nil {
        didSet { Task { await loadImage() } }
    }
    
    var output: String = ""
    var chat: [Message] = []
    var selectedModel: OpenRouterModel = DefaultsManager.shared.getModel()
    
    // MARK: - Public entry point
    
    /// Starts a streamed completion, creating a placeholder assistant message immediately.
    /// If the model requests tools, this method will execute them and then *continue streaming*
    /// by starting a new streamed request (with a new placeholder) until a normal stop.
    func stream() async throws {
        guard let currentChat = SupabaseManager.shared.currentChat else { return }
        
        // 1) Insert a placeholder assistant message in DB/UI to stream deltas into.
        let placeholder = Message(
            chatId: currentChat.id,
            role: .assistant,
            content: "",
            createdAt: Date(),
        )
        try await SupabaseManager.shared.addMessageToChat(placeholder)
        
        // 2) Perform streaming into that placeholder.
        try await performStreaming(intoPlaceholderId: placeholder.id)
    }
    
    // MARK: - Core streaming
    
    private func performStreaming(intoPlaceholderId placeholderId: UUID) async throws {
        // Build request from current messages, excluding the placeholder we just created.
        let request = try buildStreamRequest(excludingMessageId: placeholderId)
        
        // Start streaming
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw makeError("Invalid HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            // Try to read a bit of the body (if it's not SSE) for debugging.
            var bodySnippet = ""
            do {
                var collected = Data()
                for try await b in bytes {
                    collected.append(b)
                    if collected.count > 64 * 1024 { break } // cap 64KB
                }
                bodySnippet = String(data: collected, encoding: .utf8) ?? ""
            } catch { /* ignore */ }
            throw makeError("HTTP \(http.statusCode). Body: \(bodySnippet)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Accumulate tool calls by index as they stream in.
        var toolsByIndex: [Int: PendingToolCall] = [:]
        var order: [Int] = []
        
        // We read Server-Sent Events line-by-line: each `data: {json}`.
        do {
            for try await line in bytes.lines {
                if line.isEmpty || !line.hasPrefix("data:") { continue }
                let raw = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                
                if raw == "[DONE]" { break }
                guard let data = raw.data(using: .utf8) else { continue }
                
                // Attempt to decode
                let chunk: StreamChunk
                do {
                    chunk = try decoder.decode(StreamChunk.self, from: data)
                } catch {
                    // Keep going on decode errors (useful for resilience).
#if DEBUG
                    print("[DEBUG] Stream decode error: \(error)\nRAW: \(raw)")
#endif
                    continue
                }
                
                if let usage = chunk.usage {
#if DEBUG
                    print("[DEBUG] usage prompt=\(usage.promptTokens ?? 0) completion=\(usage.completionTokens ?? 0) total=\(usage.totalTokens ?? 0)")
#endif
                }
                
                guard let choice = chunk.choices.first else { continue }
                
                // 1) Normal content streaming
                if let deltaText = choice.delta.content, !deltaText.isEmpty {
                    appendToMessage(placeholderId: placeholderId, content: deltaText)
                }
                
                // 2) Tool call streaming: accumulate fragments per index
                if let deltas = choice.delta.toolCalls, !deltas.isEmpty {
                    for d in deltas {
                        let idx = d.index ?? 0
                        if toolsByIndex[idx] == nil { toolsByIndex[idx] = PendingToolCall(); order.append(idx) }
                        if let id = d.id { toolsByIndex[idx]?.id = id }
                        if let name = d.function?.name { toolsByIndex[idx]?.name = name }
                        if let frag = d.function?.arguments, !frag.isEmpty { toolsByIndex[idx]?.arguments += frag }
                        
#if DEBUG
                        print("[DEBUG] tool Δ idx=\(idx) id=\(d.id ?? "—") name=\(d.function?.name ?? "—") args+=\(d.function?.arguments ?? "")")
#endif
                    }
                }
                
                // 3) Finish handling
                if let reason = choice.finishReason {
                    switch reason {
                    case "tool_calls":
                        // Finalize tool calls, persist assistant-with-tool_calls, execute tools, and RECURSE.
                        let toolCalls = finalizedToolCalls(order: order, toolsByIndex: toolsByIndex)
                        try await handleToolCalls(toolCalls, placeholderId: placeholderId)
                        return // stop this stream; `handleToolCalls` kicks off the next one.
                    default:
                        // Normal stop (or other reasons like "length" or "content_filter")
                        return
                    }
                }
            }
        } catch is CancellationError {
            // Bubble up cancellation for callers to decide.
            throw makeError("Streaming cancelled.")
        } catch {
            throw makeError("Streaming failed: \(error.localizedDescription)")
        }
    }
    
    /// Convert accumulated pending calls into your `ToolCall` model array.
    private func finalizedToolCalls(order: [Int], toolsByIndex: [Int: PendingToolCall]) -> [ToolCall] {
        order.compactMap { idx in
            guard let b = toolsByIndex[idx],
                  let id = b.id,
                  let name = b.name
            else { return nil }
            return ToolCall(
                id: id,
                type: "function",
                function: ToolFunction(name: name, arguments: b.arguments)
            )
        }
    }
    
    // MARK: - Tool calls pipeline
    
    private func handleToolCalls(_ toolCalls: [ToolCall], placeholderId: UUID) async throws {
        guard let currentChat = SupabaseManager.shared.currentChat else { return }
        
        // Update the placeholder message with the ID we already have
        if let idx = SupabaseManager.shared.currentMessages.firstIndex(where: { $0.id == placeholderId }) {
            SupabaseManager.shared.currentMessages[idx].toolCalls = toolCalls
            if SupabaseManager.shared.currentMessages[idx].content?.isEmpty == true {
                SupabaseManager.shared.currentMessages[idx].content = nil
            }
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
    
    // MARK: - Request builder
    
    private func buildStreamRequest(excludingMessageId: UUID) throws -> URLRequest {
        var request = URLRequest(url: completionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // Use your Message.asDictionary() to preserve formatting (text, images, files, tools).
        let messagesPayload = SupabaseManager.shared.currentMessages
            .filter { $0.id != excludingMessageId }
//            .filter { $0.role != .tool }
            .map { $0.asDictionary() }
        
        var payload: [String: Any] = [
            "model": selectedModel.code,
            "messages": messagesPayload,
            "stream": true
        ]
        
        // Tools
        let tools = ToolsManager().getAllToolDefinitions()
        payload["tools"] = tools
        payload["tool_choice"] = "auto"
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        // Debug pretty payload
        if let pretty = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
           let s = String(data: pretty, encoding: .utf8) {
            print("[DEBUG] Request payload:\n\(s)")
        }
        
        return request
    }
    
    // MARK: - Helpers
    
    private func appendToMessage(placeholderId: UUID, content: String) {
        guard let idx = SupabaseManager.shared.currentMessages.lastIndex(where: { $0.id == placeholderId }) else { return }
        if SupabaseManager.shared.currentMessages[idx].content == nil {
            SupabaseManager.shared.currentMessages[idx].content = content
        } else {
            SupabaseManager.shared.currentMessages[idx].content! += content
        }
    }
    
    private func makeError(_ text: String) -> Swift.Error {
        NSError(domain: "OpenRouterAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: text])
    }
    
    // MARK: - Image/File helpers (unchanged)
    
    private func loadImage() async {
        guard let item = photoPickerItems else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            self.selectedImage = uiImage
        }
    }
    
    public func base64FromSwiftUIImage() -> String? {
        guard let image = selectedImage, let png = image.pngData() else { return nil }
        return "data:image/jpeg;base64,\(png.base64EncodedString())"
    }
    
    public func fileContent() -> String? {
        guard let fileURL = selectedFileURL else { return nil }
        return try? String(contentsOf: fileURL, encoding: .utf8)
    }
    
    public func base64FromFileURL() -> String? {
        guard let fileURL = selectedFileURL else { return nil }
        let prefix = dataURIPrefix(for: fileURL.pathExtension)
        do {
            let encoded = try Data(contentsOf: fileURL).base64EncodedString()
            return "\(prefix)\(encoded)"
        } catch {
            print("[DEBUG] Error encoding file: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func dataURIPrefix(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "data:application/pdf;base64,"
        case "txt": return "data:text/plain;base64,"
        case "csv": return "data:text/csv;base64,"
        case "json": return "data:application/json;base64,"
        case "xml": return "data:application/xml;base64,"
        case "html", "htm": return "data:text/html;base64,"
        case "md": return "data:text/markdown;base64,"
        case "rtf": return "data:application/rtf;base64,"
        case "png": return "data:image/png;base64,"
        case "jpg", "jpeg": return "data:image/jpeg;base64,"
        default: return "data:application/octet-stream;base64,"
        }
    }
    
    // MARK: - Title generation (unchanged logic, minor cleanups)
    
    public func generateChatTitle(from query: String) async throws -> String? {
        let url = URL(string: "https://openrouter.ai/api/v1/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        Given the user prompt, generate a short, concise yet effective title for a chat.
        RESPOND ONLY WITH THE TITLE.
        QUERY: \(query.trimmingCharacters(in: .whitespacesAndNewlines))
        """
        
        let payload: [String: Any] = [
            "model": "google/gemini-2.5-flash-lite",
            "prompt": prompt
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            print("[DEBUG] Failed to generate chat title: Invalid response")
            return nil
        }
        
        struct CompletionResponse: Decodable {
            struct Choice: Decodable { let text: String }
            let choices: [Choice]
        }
        
        let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
        return decoded.choices.first?.text
    }
    
    // MARK: - Generate quick summary
    public func generateQuickSummary(from query: String, url: String, content: String) async throws -> String? {
        let url = URL(string: "https://openrouter.ai/api/v1/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let MAX_GENERAL_POINTS = "2"
        let MAX_USER_POINTS = "5"
        let MAX_CHARS = "300"
        
        let prompt = """
        You are a meticulous research assistant. \
        For context today is \(Date()). \
        \
        GOAL \
        Given a USER_QUERY and the full text of one web page, produce a concise Markdown digest with: \
        (A) general key points from the page, and \
        (B) points directly relevant to USER_QUERY. \
        \
        INPUTS \
        - USER_QUERY: \(query) \
        - PAGE_URL: \(url) \
        - PAGE_TEXT (full body): \(content) \

        OUTPUT \
        Return ONLY Markdown (no code fences). Use this exact section order and keep the entire output under \(MAX_CHARS) characters total. \ 
        \
        # Title & Source \
        - **Title:** {best title or "Unknown"} \
        - **URL:** {PAGE_URL} \
        - **Published:** {ISO date if found, else "n/a"} \
        \
        # TL;DR \
        One or two short sentences summarizing the page (≤ 40 words total). \
        \
        # General Points \
        - Up to \(MAX_GENERAL_POINTS) bullets. \
        - Each bullet ≤ 22 words, de-duplicated, concrete (dates, numbers, prices/specs when available). \
        \
        # Findings for the User Query \
        Numbered list, up to \(MAX_USER_POINTS) bullets, ordered by usefulness to USER_QUERY (most useful first). For each item: \
        1. **Point:** ≤ 22 words, de-duplicated, concrete (dates, numbers, prices/specs when available). \  
        \
        RULES \
        - Write in the same language as USER_QUERY. \
        - Use ONLY facts present in PAGE_TEXT. Do not invent sources or details. \
        - Prefer concrete numbers/dates; normalize units/currencies where helpful. \
        - Strip boilerplate/marketing; merge overlapping bullets. \
        - If PAGE_TEXT has no direct relevance, state so in TL;DR and provide best-effort General Points + Missing Info.
        """
        
        let payload: [String: Any] = [
            "model": "google/gemini-2.5-flash",
            "prompt": prompt,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            print("[DEBUG] Failed to generate chat title: Invalid response")
            return nil
        }
        
        struct CompletionResponse: Decodable {
            struct Choice: Decodable { let text: String }
            let choices: [Choice]
        }
        
        let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
        return decoded.choices.first?.text
    }
}
