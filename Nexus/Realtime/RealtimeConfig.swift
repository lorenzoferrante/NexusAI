//
//  RealtimeConfig.swift
//  Nexus
//
//  Central config for the realtime voice mode.
//

import Foundation
import AVFoundation

enum RealtimeConfig {
    // Set this to your ephemeral session endpoint (see Server/realtime-ephemeral-server)
    // Example: https://your-domain.example.com/session
    static var ephemeralSessionURL: URL? = nil

    // Default model and voice. Keep in sync with your server endpoint.
    static let model: String = "gpt-realtime"
    static let voice: String = "alloy"

    // Audio format parameters for realtime streaming
    static let targetSampleRate: Double = 16_000 // PCM16 mono 16kHz
    static let channels: AVAudioChannelCount = 1
}
