import Foundation
import AVFoundation

@MainActor
final class RealtimeVoiceClient: NSObject, ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let apiKeyProvider: () -> String?
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
    @Published private(set) var isRecording = false

    init(apiKeyProvider: @escaping () -> String? = { Keychain.load(Keychain.OPENAI_API_KEY) }) {
        self.apiKeyProvider = apiKeyProvider
        super.init()
        configureAudio()
    }

    private func configureAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.setPreferredSampleRate(16_000)
        try? session.setActive(true)
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.outputNode, format: format)
    }

    func connect() {
        guard let key = apiKeyProvider() else {
            print("[Realtime] Missing API key")
            return
        }
        var request = URLRequest(url: URL(string: "wss://api.openai.com/v1/realtime?model=gpt-realtime")!)
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        receive()
        try? audioEngine.start()
        playerNode.play()
    }

    func disconnect() {
        stopRecording()
        audioEngine.stop()
        playerNode.stop()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        let input = audioEngine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.sendAudio(buffer: buffer)
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        audioEngine.inputNode.removeTap(onBus: 0)
        send(["type": "input_audio_buffer.commit"])
        send([
            "type": "response.create",
            "response": [
                "modalities": ["audio"],
                "audio": ["voice": "alloy", "format": "wav"]
            ]
        ])
    }

    private func sendAudio(buffer: AVAudioPCMBuffer) {
        guard let data = buffer.toData() else { return }
        let payload: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": data.base64EncodedString()
        ]
        send(payload)
    }

    private func send(_ json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }
        webSocketTask?.send(.data(data)) { error in
            if let error = error {
                print("[Realtime] send error: \(error)")
            }
        }
    }

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.handle(data: data)
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self.handle(data: data)
                    }
                @unknown default:
                    break
                }
                self.receive()
            case .failure(let error):
                print("[Realtime] receive error: \(error)")
            }
        }
    }

    private func handle(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        if type == "response.audio.delta",
           let delta = json["delta"] as? String,
           let audioData = Data(base64Encoded: delta),
           let buffer = audioData.toPCMBuffer(format: format) {
            playerNode.scheduleBuffer(buffer, at: nil, options: [])
            if !playerNode.isPlaying { playerNode.play() }
        }
    }
}

private extension AVAudioPCMBuffer {
    func toData() -> Data? {
        guard let channel = int16ChannelData?[0] else { return nil }
        let length = Int(frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: channel, count: length)
    }
}

private extension Data {
    func toPCMBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCapacity = UInt32(count) / UInt32(MemoryLayout<Int16>.size)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        buffer.frameLength = frameCapacity
        self.copyBytes(to: buffer.int16ChannelData![0], count: count)
        return buffer
    }
}

