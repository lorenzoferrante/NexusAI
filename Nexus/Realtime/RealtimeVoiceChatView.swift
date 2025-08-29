import SwiftUI

struct RealtimeVoiceChatView: View {
    @StateObject private var client = RealtimeVoiceClient()

    var body: some View {
        VStack {
            Spacer()
            Button(action: {
                if client.isRecording {
                    client.stopRecording()
                } else {
                    client.startRecording()
                }
            }) {
                Image(systemName: client.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(client.isRecording ? .red : .green)
            }
            Spacer()
        }
        .navigationTitle("Realtime Voice")
        .onAppear { client.connect() }
        .onDisappear { client.disconnect() }
    }
}

#Preview {
    RealtimeVoiceChatView()
}
