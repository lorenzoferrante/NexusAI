RealtimeVoiceChat (React Native)

Voice-to-voice chat with OpenAI Realtime (WebRTC) using react-native-webrtc. Press and hold to talk; the model responds in voice, with live text transcripts shown in a chat UI.

Prereqs
- Xcode (iOS) and/or Android Studio (Android)
- Node 18+
- CocoaPods (for iOS): `sudo gem install cocoapods`
- An ephemeral token server running and reachable from the device

Ephemeral Session Server
- This repo contains `realtime-ephemeral-server/server.js` which issues short-lived session tokens.
- Ensure it has access to your OpenAI API key. Either:
  - Create `realtime-ephemeral-server/.env` with `OPENAI_API_KEY=sk-...`, or
  - Start it with the env var: `OPENAI_API_KEY=sk-... npm start`

Run it:
```
cd ../realtime-ephemeral-server
npm install
OPENAI_API_KEY=sk-... npm start  # or put it in .env in this folder
```
By default it listens on http://localhost:8787 and returns JSON with `client_secret.value`.

Install App Dependencies
```
cd RealtimeVoiceChat
npm install
npm install react-native-webrtc @types/webrtc --save
```

iOS Setup
```
cd ios
pod install
cd ..
npm run ios
```
If you run the iOS Simulator on the same machine as the ephemeral server, `localhost:8787` works.

Android Setup
```
npm run android
```
- Emulator uses `http://10.0.2.2:8787` automatically. For a physical device, update server URL to your machine’s LAN IP in `src/config.ts`.
- Grant microphone permission when prompted.

What It Does
- Creates a WebRTC PeerConnection directly to `v1/realtime?model=gpt-realtime` using a short-lived token from `/session`.
- Adds your microphone as an audio track; a remote audio track is played back automatically.
- A DataChannel (`oai-events`) streams events for transcripts; the UI shows partial and final text for both user and assistant.
- Push-to-talk button toggles mic track `enabled` so the server VAD can segment turns.

Key Files
- `src/realtime/OpenAIRealtimeClient.ts`: WebRTC setup, token fetch, SDP exchange, event handling.
- `App.tsx`: Minimal chat UI with connection status and press-to-talk.
- `ios/RealtimeVoiceChat/Info.plist`: Adds `NSMicrophoneUsageDescription`.
- `android/app/src/main/AndroidManifest.xml`: Adds `RECORD_AUDIO` permission.

Notes
- For real devices, set the ephemeral server base URL in `src/config.ts` to your machine’s LAN IP.
- The ephemeral server preconfigures voice and formats. You can adjust defaults via `session.update` in the client or env in the server.
- On first iOS build you may need to open `ios/RealtimeVoiceChat.xcworkspace` in Xcode to accept signing provisioning.

