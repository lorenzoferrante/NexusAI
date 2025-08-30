//
//  RealtimeVoiceView.swift
//  Nexus
//
//  Minimal push-to-talk UI for realtime voice.
//

import SwiftUI

struct RealtimeVoiceView: View {
    @State var client = RealtimeVoiceManager()
    @State var isPressing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BackView()
            VStack(spacing: 20) {
                statusRow
                transcriptView
                Spacer()
                micButton
            }
            .padding()
        }
        .navigationTitle("Voice Mode")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear { client.connect() }
        .onDisappear { client.disconnect() }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(client.partialText.isEmpty ? client.finalText : client.partialText)
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        }
    }

    private var micButton: some View {
        let baseSize: CGFloat = 90
        let scale = 1.0 + CGFloat(client.level) * 0.2
        return Button(action: {}) {
            Image(systemName: client.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: baseSize, height: baseSize)
                .background(Circle().fill(ThemeColors.from(color: DefaultsManager.shared.getThemeColor())))
                .scaleEffect(scale)
                .shadow(radius: 12)
        }
        .onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { isPressing in
            if isPressing {
                if !client.isRecording { client.startRecording() }
            } else {
                client.stopRecordingAndSend()
            }
        })
        .accessibilityLabel(client.isRecording ? "Recording. Release to send." : "Hold to talk")
    }

    private var statusText: String {
        switch client.state {
        case .idle: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected: return client.isRecording ? "Listening…" : "Ready"
        case .error(let message): return "Error: \(message)"
        }
    }

    private var statusColor: Color {
        switch client.state {
        case .idle: return .gray
        case .connecting: return .yellow
        case .connected: return client.isRecording ? .red : .green
        case .error: return .orange
        }
    }
}

#Preview {
    NavigationStack { RealtimeVoiceView() }
        .preferredColorScheme(.dark)
}
