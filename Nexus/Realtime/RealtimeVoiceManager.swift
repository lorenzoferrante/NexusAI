//
//  RealtimeVoiceManager.swift
//  Nexus
//
//  Streams mic audio to OpenAI Realtime via WebSocket and plays streamed audio replies.
//

import Foundation
import AVFoundation

@Observable
class RealtimeVoiceManager: NSObject {
    enum State {
        case idle
        case connecting
        case connected
        case error(String)
    }

    // MARK: - Public state
    var state: State = .idle
    var isRecording: Bool = false
    var isPlaying: Bool = false
    var level: Float = 0 // 0...1 peak level for UI
    var partialText: String = ""
    var finalText: String = ""

    // MARK: - Private
    private var ws: URLSessionWebSocketTask?
    private var wsSession: URLSession?
    private var pingTimer: Timer?

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let inputMixer = AVAudioMixerNode()
    private var inputConverter: AVAudioConverter?
    private var micTapInstalled: Bool = false
    private var appendedFramesThisTurn: Int64 = 0
    private var responseInProgress: Bool = false
    private let commitDelayMsIfSilent: Int = 180

    private let playbackFormat = AVAudioFormat(standardFormatWithSampleRate: RealtimeConfig.targetSampleRate, channels: RealtimeConfig.channels)!

    private let queue = DispatchQueue(label: "realtime.voice.manager.queue")

    // MARK: - Lifecycle
    func connect() {
        guard case .idle = state else { return }
        state = .connecting
        Task { await setupAndConnect() }
    }

    func disconnect() {
        stopRecordingInternal()
        stopPlayback()
        pingTimer?.invalidate()
        pingTimer = nil
        ws?.cancel(with: .goingAway, reason: nil)
        ws = nil
        wsSession?.invalidateAndCancel()
        wsSession = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        state = .idle
    }

    // MARK: - Recording control
    func startRecording() {
        guard case .connected = state, !isRecording else { return }
        appendedFramesThisTurn = 0
        isRecording = true
        // Clear any previous uncommitted audio just in case
        sendJSON(["type": "input_audio_buffer.clear"]) { }
        // If assistant is currently responding, cancel and stop playback (barge-in)
        if responseInProgress || isPlaying {
            sendJSON(["type": "response.cancel"]) { [weak self] in
                self?.stopPlayback()
            }
        }
        installMicTap()
    }

    func stopRecordingAndSend() {
        guard isRecording else { return }
        // Ensure at least 100ms of audio is present before commit
        let msAvailable = Int(Double(appendedFramesThisTurn) / RealtimeConfig.targetSampleRate * 1000.0)
        if msAvailable < 100 {
            let needed = max(0, 140 - msAvailable)
            appendSilence(milliseconds: needed) { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(self.commitDelayMsIfSilent)) {
                    self.commitAndCreateRespectingActiveResponse()
                }
            }
        } else {
            commitAndCreateRespectingActiveResponse()
        }
        // Remove tap after events are queued
        stopRecordingInternal()
    }

    private func commitAndCreateRespectingActiveResponse() {
        if responseInProgress {
            // Cancel current response, then commit and create after a brief delay
            sendJSON(["type": "response.cancel"]) { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
                    self.sendJSON(["type": "input_audio_buffer.commit"]) { [weak self] in
                        guard let self = self else { return }
                        self.responseInProgress = true
                        self.sendJSON([
                            "type": "response.create",
                            "response": [
                                "modalities": ["audio", "text"],
                                "instructions": "Please answer concisely and speak the reply.",
                                "conversation": "auto"
                            ]
                        ])
                    }
                }
            }
        } else {
            sendJSON(["type": "input_audio_buffer.commit"]) { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(60)) {
                    self.responseInProgress = true
                    self.sendJSON([
                        "type": "response.create",
                        "response": [
                            "modalities": ["audio", "text"],
                            "instructions": "Please answer concisely and speak the reply.",
                            "conversation": "auto"
                        ]
                    ])
                }
            }
        }
    }

    // MARK: - Setup
    @MainActor
    private func setupAndConnect() async {
        do {
            try configureAudioSession()
            try await ensureMicPermission()
            setupEngineGraph()
            engine.prepare()
            try engine.start()
            try await openWebSocket()
            state = .connected
            startReceiveLoop()
            startPing()
            // Configure session (sample rate is implied for pcm16; no explicit field)
            sendJSON([
                "type": "session.update",
                "session": [
                    "voice": RealtimeConfig.voice,
                    "modalities": ["text", "audio"],
                    "input_audio_format": "pcm16",
                    "output_audio_format": "pcm16",
                    "instructions": "You are a concise, friendly assistant. Respond briefly and clearly."
                ]
            ])
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func configureAudioSession() throws {
        let sess = AVAudioSession.sharedInstance()
        try sess.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        // Set preferences before activation
        try? sess.setPreferredInputNumberOfChannels(Int(RealtimeConfig.channels))
        try? sess.setPreferredSampleRate(RealtimeConfig.targetSampleRate)
        try? sess.setPreferredIOBufferDuration(0.02) // ~20ms buffers
        try sess.setActive(true)
        try? sess.overrideOutputAudioPort(.speaker)
    }

    private func ensureMicPermission() async throws {
        let sess = AVAudioSession.sharedInstance()
        switch sess.recordPermission {
        case .granted:
            return
        case .denied:
            throw NSError(domain: "Realtime", code: 10, userInfo: [NSLocalizedDescriptionKey: "Microphone access is denied in Settings"])
        case .undetermined:
            let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                sess.requestRecordPermission { cont.resume(returning: $0) }
            }
            if !granted {
                throw NSError(domain: "Realtime", code: 11, userInfo: [NSLocalizedDescriptionKey: "Microphone permission not granted"])
            }
        @unknown default:
            return
        }
    }

    private func setupEngineGraph() {
        // Ensure input path is active by routing input -> muted mixer -> main mixer
        if engine.attachedNodes.contains(inputMixer) == false {
            engine.attach(inputMixer)
            inputMixer.outputVolume = 0
            let input = engine.inputNode
            let inFormat = input.outputFormat(forBus: 0)
            engine.connect(input, to: inputMixer, format: inFormat)
            engine.connect(inputMixer, to: engine.mainMixerNode, format: inFormat)
        }

        if engine.attachedNodes.contains(playerNode) == false {
            engine.attach(playerNode)
            // Let the engine choose a compatible format; it will SRC from scheduled buffers.
            engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        }
        // Do not start the player until there is audio to play
    }

    private func installMicTap() {
        let input = engine.inputNode
        // Remove any existing tap before installing a new one
        if micTapInstalled {
            input.removeTap(onBus: 0)
            micTapInstalled = false
        }
        // Use the node's output format and let installTap infer the format (nil)
        let inputFormat = input.outputFormat(forBus: 0)
        let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: RealtimeConfig.targetSampleRate, channels: RealtimeConfig.channels, interleaved: false)!
        inputConverter = AVAudioConverter(from: inputFormat, to: desiredFormat)

        // ~20ms at 48kHz ~= 960 frames; use 1024 for convenience
        let bufferSize: AVAudioFrameCount = 1024

        input.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] buffer, time in
            guard let self = self, self.isRecording else { return }
            guard let converter = self.inputConverter else { return }

            let inRate = inputFormat.sampleRate > 0 ? inputFormat.sampleRate : desiredFormat.sampleRate
            let outCapacity = AVAudioFrameCount((Double(buffer.frameLength) / inRate) * desiredFormat.sampleRate) + 64
            guard let outBuffer = AVAudioPCMBuffer(pcmFormat: desiredFormat, frameCapacity: outCapacity) else { return }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            converter.convert(to: outBuffer, error: &error, withInputFrom: inputBlock)
            if let error { print("[Realtime] convert error: \(error.localizedDescription)") }

            // AVAudioConverter sets frameLength
            self.appendedFramesThisTurn += Int64(outBuffer.frameLength)
            self.processMicChunk(buffer: outBuffer)
        }
        micTapInstalled = true
    }

    private func stopRecordingInternal() {
        // Safely remove tap if present
        if micTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            micTapInstalled = false
        }
        isRecording = false
    }

    private func stopPlayback() {
        if playerNode.isPlaying { playerNode.stop() }
        isPlaying = false
    }

    // MARK: - WebSocket
    private func openWebSocket() async throws {
        let token = "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"

        // 2) Open WebSocket to OpenAI Realtime
        var req = URLRequest(url: URL(string: "wss://api.openai.com/v1/realtime?model=\(RealtimeConfig.model)")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let conf = URLSessionConfiguration.default
        wsSession = URLSession(configuration: conf, delegate: self, delegateQueue: nil)
        let task = wsSession!.webSocketTask(with: req)
        task.resume()
        ws = task
    }

    private static func parseEphemeralToken(from data: Data) throws -> String {
        // Expecting OpenAI response for session with a client_secret.value token
        struct ClientSecret: Decodable { let value: String? }
        struct SessionResp: Decodable { let client_secret: ClientSecret?; let client_secret_value: String? }
        if let s = try? JSONDecoder().decode(SessionResp.self, from: data) {
            if let v = s.client_secret?.value { return v }
            if let v = s.client_secret_value { return v }
        }
        // Try generic JSON
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let cs = obj["client_secret"] as? [String: Any], let v = cs["value"] as? String { return v }
            if let v = obj["client_secret_value"] as? String { return v }
        }
        throw NSError(domain: "Realtime", code: 3, userInfo: [NSLocalizedDescriptionKey: "Ephemeral token missing in response"])
    }

    private func startReceiveLoop() {
        ws?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async { self.state = .error(error.localizedDescription) }
            case .success(let message):
                self.handle(message)
                self.startReceiveLoop()
            }
        }
    }

    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.ws?.sendPing { err in if let err { print("[Realtime] ping error: \(err)") } }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleJSONString(text)
        case .data(let data):
            // Realtime may also send JSON as binary frames; try decode
            if let str = String(data: data, encoding: .utf8) { handleJSONString(str) }
        @unknown default:
            break
        }
    }

    private func handleJSONString(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let type = obj["type"] as? String else {
            return
        }
        switch type {
        case "response.created", "response.started":
            if let rid = obj["response"] as? [String: Any], let id = rid["id"] as? String { print("[Realtime][RX] response started: \(id)") }
            DispatchQueue.main.async { self.responseInProgress = true }
        case "response.output_audio.delta", "response.audio.delta":
            if let b64 = obj["audio"] as? String {
                print("[Realtime][RX] audio delta bytes=\(Data(base64Encoded: b64)?.count ?? -1)")
                handleAudioDelta(base64: b64)
            }
            DispatchQueue.main.async { self.responseInProgress = true }
        case "response.output_text.delta", "response.text.delta", "response.delta":
            if let delta = obj["delta"] as? String {
                print("[Realtime][RX] text delta len=\(delta.count)")
                DispatchQueue.main.async { self.partialText += delta }
            }
            DispatchQueue.main.async { self.responseInProgress = true }
        case "response.audio_transcript.delta":
            if let delta = obj["delta"] as? String {
                print("[Realtime][RX] audio transcript delta len=\(delta.count)")
                DispatchQueue.main.async { self.partialText += delta }
            }
            DispatchQueue.main.async { self.responseInProgress = true }
        case "response.canceled", "response.completed", "response.done":
            DispatchQueue.main.async {
                self.finalText = self.partialText
                self.partialText = ""
                self.responseInProgress = false
            }
        case "error":
            let msg = (obj["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
            DispatchQueue.main.async { self.state = .error(msg) }
        default:
            print("[Realtime][RX] Unhandled type=\(type) payload=\(obj)")
        }
    }

    private func sendJSON(_ obj: [String: Any], completion: (() -> Void)? = nil) {
        guard let ws else { completion?(); return }
        guard let data = try? JSONSerialization.data(withJSONObject: obj), let str = String(data: data, encoding: .utf8) else { completion?(); return }
        print("[Realtime][TX] \(str)")
        ws.send(.string(str)) { err in
            if let err { print("[Realtime] send error: \(err)") }
            completion?()
        }
    }

    // MARK: - Audio I/O helpers
    private func processMicChunk(buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)

        // Compute level
        var peak: Float = 0
        for i in 0..<frames { peak = max(peak, fabsf(channel[i])) }
        DispatchQueue.main.async { self.level = min(1.0, peak) }

        // Convert float32 mono [-1,1] to PCM16LE bytes
        var data = Data(count: frames * 2)
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            let out = ptr.bindMemory(to: Int16.self)
            for i in 0..<frames {
                let v = max(-1.0, min(1.0, channel[i]))
                out[i] = Int16(v * Float(Int16.max))
            }
        }
        let b64 = data.base64EncodedString()
        sendJSON(["type": "input_audio_buffer.append", "audio": b64])
    }

    private func appendSilence(milliseconds: Int, completion: (() -> Void)? = nil) {
        guard milliseconds > 0 else { completion?(); return }
        let frames = Int(RealtimeConfig.targetSampleRate * Double(milliseconds) / 1000.0)
        if frames <= 0 { completion?(); return }
        let bytes = frames * 2 // PCM16 mono
        let data = Data(count: bytes) // zeroed
        let b64 = data.base64EncodedString()
        appendedFramesThisTurn += Int64(frames)
        sendJSON(["type": "input_audio_buffer.append", "audio": b64], completion: completion)
    }

    private func handleAudioDelta(base64: String) {
        guard let data = Data(base64Encoded: base64) else { return }
        // Convert PCM16LE -> Float32 buffer at 16k, schedule for playback
        let frames = data.count / 2
        guard let buf = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: AVAudioFrameCount(frames)) else { return }
        buf.frameLength = AVAudioFrameCount(frames)
        guard let dst = buf.floatChannelData?[0] else { return }
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let src = ptr.bindMemory(to: Int16.self)
            for i in 0..<frames {
                dst[i] = Float(src[i]) / Float(Int16.max)
            }
        }
        playerNode.scheduleBuffer(buf, completionHandler: nil)
        print("[Realtime][AUDIO] scheduled \(frames) frames")
        if !playerNode.isPlaying {
            playerNode.play()
            isPlaying = true
        }
    }
}

extension RealtimeVoiceManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async { self.state = .connected }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async { self.state = .idle }
    }
}
