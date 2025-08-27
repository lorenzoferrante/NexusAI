//
//  OpenRouterStreamingClient.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 18/08/25.
//

import Foundation
import UIKit

// Tool call incremental piece (OpenAI/OpenRouter delta shape)
public struct ToolCallFragment: Equatable {
    public let index: Int
    public var id: String?              // may arrive late
    public var name: String?            // function name
    public var argumentsJSON: String = "" // arguments arrive chunked; concatenate strings
}

/// A robust SSE client for OpenRouter /chat/completions streaming.
/// - Handles: partial tokens, tool_calls deltas, stalls, foreground/background, cancel, and resume.
/// - Policy: auto-retry is allowed only when **no tokens** were received (to avoid double-billing).
public final class OpenRouterStreamClient: NSObject, URLSessionDataDelegate {
    // MARK: Public types
    
    public struct Config {
        /// Pull your user API key from Keychain on demand (don’t capture a stale copy).
        public var apiKeyProvider: () -> String?
        /// Optional attribution headers (recommended by OpenRouter).
        public var referer: String? = nil
        public var title: String? = nil
        /// Consider the stream stalled if no bytes (including SSE comments) arrive for this long.
        public var stallTimeout: TimeInterval = 20
        /// URLSession timeouts.
        public var requestTimeout: TimeInterval = 120
        public var resourceTimeout: TimeInterval = 600
        /// Background grace (how long we keep the app alive to tidy up on background).
        public var backgroundGrace: TimeInterval = 6
        
        /// If true, the client will attempt to auto-resume when the app returns to foreground.
        public var autoResumeOnForeground: Bool = true
        /// When partial tokens were received, provide a conversation continuation.
        /// Return the full `messages` array to send (e.g., append a "Continue." user turn).
        /// If this closure returns nil, auto-resume is skipped.
        public var continuationBuilder: (([String: Any]) -> [[String: Any]]?)? = nil
        
        public init(apiKeyProvider: @escaping () -> String?) {
            self.apiKeyProvider = apiKeyProvider
        }
    }
    
    public enum ResumeStrategy {
        /// Start a **new** request that continues from the partial (e.g., by appending "continue" yourself).
        case continueFromPartial
        /// Retry the same prompt exactly. Use only when **no tokens** were received previously.
        case retrySamePrompt
    }
    
    public enum StreamState: Equatable {
        case idle
        case streaming
        case finished(reason: String?)
        case cancelled
        case failed(message: String)
    }
    
    private var lastBody: [String: Any]?
    private var lastFinishReason: String? = nil
    private var pendingToolCallIDs: [String] = []
    private var hasPendingToolCalls: Bool { !pendingToolCallIDs.isEmpty }
    
    // MARK: Public callbacks
    
    public struct Handlers {
        /// Fires whenever new content tokens arrive.
        public var onToken: (String) -> Void
        /// Fires whenever new reasoning tokens arrive.
        public var onReasoningToken: (String) -> Void
        /// Fires whenever new Image data arrive.
        public var onImageDelta: ([ImageStruct]) -> Void
        /// Fires as tool_calls deltas arrive (indexed).
        public var onToolCallDelta: (ToolCallFragment) -> Void
        /// Fires when the stream completes normally (finish_reason).
        public var onFinish: (_ finishReason: String?) -> Void
        /// Fires for any terminal error (network/server/stall/cancel).
        public var onError: (_ message: String) -> Void
        /// Optional: called when state changes (observability).
        public var onStateChange: ((StreamState) -> Void)?
        
        public init(
            onToken: @escaping (String) -> Void,
            onReasoningToken: @escaping (String) -> Void,
            onImageDelta: @escaping ([ImageStruct]) -> Void,
            onToolCallDelta: @escaping (ToolCallFragment) -> Void,
            onFinish: @escaping (String?) -> Void,
            onError: @escaping (String) -> Void,
            onStateChange: ((StreamState) -> Void)? = nil
        ) {
            self.onToken = onToken
            self.onReasoningToken = onReasoningToken
            self.onImageDelta = onImageDelta
            self.onToolCallDelta = onToolCallDelta
            self.onFinish = onFinish
            self.onError = onError
            self.onStateChange = onStateChange
        }
    }
    
    // MARK: Public API
    
    public init(config: Config) {
        // Initialize own stored properties before calling super.init
        self.config = config
        super.init()
        
        // Observe foreground/background to gracefully cancel & persist partials if needed.
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stallTimer?.invalidate()
        task?.cancel()
        // Avoid initializing the lazy session just to invalidate; only do it if it was created.
        if sessionInitialized {
            session.invalidateAndCancel()
        }
    }
    
    /// Starts a streaming request. If a stream is already running, it will be cancelled first.
    /// - Parameters:
    ///   - body: Standard OpenAI-style body. `stream = true` is forced.
    ///   - handlers: Token / tool call / finish / error callbacks.
    public func startStreaming(
        body: [String: Any],
        handlers: Handlers
    ) {
        pendingToolCallIDs.removeAll()
        lastFinishReason = nil
        
        stopStreaming(savePartial: true) // clean any prior stream
        self.handlers = handlers
        self.partialReceived = false
        self.toolCallBuffer.removeAll()
        self.state = .streaming
        self.lastBody = body
        // Reset HTTP tracking before a new request
        httpStatusCode = nil
        errorBuffer.removeAll(keepingCapacity: false)
        
        guard let key = config.apiKeyProvider(), !key.isEmpty else {
            fail("Missing OpenRouter API key")
            return
        }
        
        // Build request
        guard let req = buildStreamRequest(apiKey: key, body: body) else {
            fail("Failed to build request")
            return
        }
        
        // Start
        self.task = session.dataTask(with: req)
        self.task?.resume()
        lastEventAt = Date()
        scheduleStallTimer()
        beginBackgroundTaskIfNeeded()
        notifyState()
    }
    
    /// Cancels the current stream. If `savePartial` is false, you can clear your in-UI partial.
    public func stopStreaming(savePartial: Bool) {
        stallTimer?.invalidate()
        task?.cancel()
        task = nil
        endBackgroundTask()
        if state == .streaming { state = .cancelled; notifyState() }
        // Your UI decides what to do with partial content.
    }
    
    /// Resumes after an interruption according to a strategy.
    /// - Note: "Resume" is always a **new** request. You cannot resume the exact same socket.
    public func resume(
        strategy: ResumeStrategy,
        originalBody: [String: Any],
        continuedMessages: [[String: Any]]? = nil
    ) {
        switch strategy {
        case .retrySamePrompt:
            // Safe only if **no tokens** arrived previously.
            guard !partialReceived else {
                fail("Unsafe resume: partial tokens were already received; choose .continueFromPartial")
                return
            }
            startStreaming(body: forcingStream(originalBody), handlers: handlers!)
            
        case .continueFromPartial:
            // Caller provides a new messages array that “continues” (e.g., append “Continue.”).
            guard let msgs = continuedMessages else {
                fail("Missing continuedMessages for .continueFromPartial")
                return
            }
            var b = originalBody
            b["messages"] = msgs
            startStreaming(body: forcingStream(b), handlers: handlers!)
        }
    }
    
    /// Current streaming state.
    public private(set) var state: StreamState = .idle
    
    // MARK: Private
    
    private let config: Config
    // Create the URLSession lazily so `self` can be used safely as the delegate after init completes.
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = config.requestTimeout
        cfg.timeoutIntervalForResource = config.resourceTimeout
        sessionInitialized = true
        return URLSession(configuration: cfg, delegate: self, delegateQueue: .main)
    }()
    private var sessionInitialized = false
    
    private var task: URLSessionDataTask?
    private var handlers: Handlers?
    
    private var buffer = Data()
    // Track HTTP status to distinguish SSE vs JSON error bodies
    private var httpStatusCode: Int? = nil
    private var errorBuffer = Data()
    
    private var lastEventAt = Date()
    private var stallTimer: Timer?
    private var partialReceived = false
    
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    
    // toolCalls are delivered incrementally; keep a buffer per index.
    private var toolCallBuffer: [Int: ToolCallFragment] = [:]
    
    private func forcingStream(_ body: [String: Any]) -> [String: Any] {
        var copy = body
        copy["stream"] = true
        return copy
    }
    
    private func buildStreamRequest(apiKey: String, body: [String: Any]) -> URLRequest? {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept") // request SSE explicitly
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let r = config.referer { req.setValue(r, forHTTPHeaderField: "HTTP-Referer") }
        if let t = config.title { req.setValue(t, forHTTPHeaderField: "X-Title") }
        
        let bodyWithStream = forcingStream(body)
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: bodyWithStream, options: [])
            return req
        } catch {
            return nil
        }
    }
    
    private func scheduleStallTimer() {
        stallTimer?.invalidate()
        stallTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            if Date().timeIntervalSince(self.lastEventAt) > self.config.stallTimeout {
                self.fail("Stream stalled")
            }
        }
    }
    
    private func beginBackgroundTaskIfNeeded() {
        guard bgTask == .invalid else { return }
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "openrouter.stream.wrapup") { [weak self] in
            // Time’s up—cleanly cancel.
            self?.stopStreaming(savePartial: true)
        }
        // End automatically after grace unless we end earlier.
        DispatchQueue.main.asyncAfter(deadline: .now() + config.backgroundGrace) { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
    }
    
    private func notifyState() { handlers?.onStateChange?(state) }
    
    private func fail(_ message: String) {
        stallTimer?.invalidate()
        task?.cancel()
        task = nil
        endBackgroundTask()
        state = .failed(message: message)
        handlers?.onError(message)
        notifyState()
    }
    
    // MARK: App lifecycle hooks
    
    @objc private func appWillResignActive() {
        // iOS will suspend sockets shortly; cancel cleanly and keep partials.
        stopStreaming(savePartial: true)
    }
    
    @MainActor
    @objc public func appDidBecomeActive() {
        // Only auto-resume when explicitly enabled to avoid accidental double-billing.
        guard config.autoResumeOnForeground else { return }
        guard let original = lastBody else { return }
        if hasPendingToolCalls { return } // ← let the tool runner finish step-2
        if partialReceived {
            guard let builder = config.continuationBuilder,
                  let continued = builder(original) else { return }
            resume(strategy: .continueFromPartial, originalBody: original, continuedMessages: continued)
        } else {
            
        }
    }
    
    // MARK: URLSessionDataDelegate
    
    // Capture HTTP status so we can distinguish SSE vs JSON errors
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse {
            httpStatusCode = http.statusCode
        }
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lastEventAt = Date()
        buffer.append(data)
        
        // If this is an HTTP error response, accumulate JSON body and skip SSE parsing
        if let code = httpStatusCode, code >= 400 {
            errorBuffer.append(data)
            return
        }
        
        // SSE events are separated by a blank line ("\n\n" or "\r\n\r\n").
        let lf2 = Data("\n\n".utf8)
        let crlf2 = Data("\r\n\r\n".utf8)
        while true {
            let r1 = buffer.range(of: lf2)
            let r2 = buffer.range(of: crlf2)
            let chosen: Range<Data.Index>?
            switch (r1, r2) {
            case let (a?, b?):
                chosen = (a.lowerBound < b.lowerBound) ? a : b
            case let (a?, nil):
                chosen = a
            case let (nil, b?):
                chosen = b
            default:
                chosen = nil
            }
            guard let range = chosen else { break }
            let chunk = buffer.subdata(in: buffer.startIndex ..< range.lowerBound)
            buffer.removeSubrange(buffer.startIndex ..< range.upperBound)
            handleSSEChunk(chunk)
        }
    }
    
    @MainActor public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        stallTimer?.invalidate()
        endBackgroundTask()
        
        // First: surface HTTP error JSON instead of finishing silently
        if let code = httpStatusCode, code >= 400 {
            if !errorBuffer.isEmpty,
               let obj = try? JSONSerialization.jsonObject(with: errorBuffer) as? [String: Any],
               let err = obj["error"] as? [String: Any] {
                let msg = (err["message"] as? String) ?? "HTTP \(code)"
                if let md = err["metadata"] as? [String: Any],
                   let raw = md["raw"] as? String, !raw.isEmpty {
                    // Log raw for debugging (don’t show to users)
                    print("[OpenRouter raw error] \(raw)")
                }
                fail(msg); return
            }
            fail("HTTP \(code)"); return
        }
        
        if let err = error as NSError?, err.code == NSURLErrorCancelled {
            // Normal cancel path already notified.
            return
        }
        if let error {
            fail(error.localizedDescription)
            return
        }
        // If server ended cleanly but we didn’t catch a finish_reason, treat as finished.
        if case .streaming = state {
            state = .finished(reason: nil)
            handlers?.onFinish(nil)
            notifyState()
        }
    }
    
    // MARK: SSE parsing
    
    private func handleSSEChunk(_ data: Data) {
        guard let raw = String(data: data, encoding: .utf8) else { return }
        debugPrint("[DEBUG] Chunk: \(raw)")
        
        
        // Ignore comment heartbeats like ": OPENROUTER PROCESSING"
        if raw.hasPrefix(":") { return }
        
        // Extract concatenated `data:` lines per SSE spec.
        var payload = ""
        for line in raw.split(separator: "\n") {
            if line.hasPrefix("data:") {
                payload += String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            }
        }
        guard !payload.isEmpty else { return }
        
        // Minimal chunk types for OpenAI/OpenRouter
        struct Chunk: Decodable {
            struct Choice: Decodable {
                struct Delta: Decodable {
                    struct ToolCall: Decodable {
                        struct Function: Decodable { let name: String?; let arguments: String? }
                        let index: Int
                        let id: String?
                        let type: String?
                        let function: Function?
                    }
                    let role: String?
                    let reasoning: String?
                    let content: String?
                    let images: [ImageStruct]?
                    let tool_calls: [ToolCall]?
                }
                let delta: Delta?
                let finish_reason: String?
            }
            let choices: [Choice]?
        }
        
        guard let dataJSON = payload.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(Chunk.self, from: dataJSON),
              let choices = chunk.choices, !choices.isEmpty
        else { return }
        
        // 1) Content deltas
        var anyContent = false
        for c in choices {
            if let images = c.delta?.images, !images.isEmpty {
                partialReceived = true
                anyContent = true
                handlers?.onImageDelta(images)
            }
            
            if let reasoning = c.delta?.reasoning, !reasoning.isEmpty {
                partialReceived = true
                anyContent = true
                handlers?.onReasoningToken(reasoning)
            }
            
            if let content = c.delta?.content, !content.isEmpty {
                partialReceived = true
                anyContent = true
                handlers?.onToken(content)
            }
            
            // 2) Tool call deltas
            if let deltas = c.delta?.tool_calls, !deltas.isEmpty {
                for d in deltas {
                    var item = toolCallBuffer[d.index] ?? ToolCallFragment(index: d.index, id: d.id, name: d.function?.name, argumentsJSON: "")
                    if let id = d.id, item.id == nil { item.id = id }
                    if let name = d.function?.name, item.name == nil || item.name!.isEmpty { item.name = name }
                    if let args = d.function?.arguments, !args.isEmpty {
                        item.argumentsJSON.append(args)
                    }
                    toolCallBuffer[d.index] = item
                    handlers?.onToolCallDelta(item)
                }
            }
            
            // 3) Finish
            if let finish = c.finish_reason, !finish.isEmpty, finish != "null" {
                lastFinishReason = finish
                if finish == "tool_calls" {
                    // collect ids we saw so caller can attach results to the right ids
                    pendingToolCallIDs = toolCallBuffer
                        .sorted { $0.key < $1.key }
                        .compactMap { $0.value.id }
                } else {
                    pendingToolCallIDs.removeAll()
                }
                stallTimer?.invalidate()
                endBackgroundTask()
                state = .finished(reason: finish)
                partialReceived = false
                handlers?.onFinish(finish)
                notifyState()
            }
        }
        
        if anyContent {
            lastEventAt = Date()
        }
    }
}
