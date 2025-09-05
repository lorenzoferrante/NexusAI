// Optional: override for all platforms (e.g., your LAN IP or https ngrok)
export const OVERRIDE_SERVER_URL = '';

export const getEphemeralServerBaseURL = () => {
  // iOS Simulator can use localhost; Android emulator needs 10.0.2.2
  // For a physical device, replace with your machine's LAN IP (e.g., http://192.168.1.10:8787)
  const port = 8787;
  if (OVERRIDE_SERVER_URL) return OVERRIDE_SERVER_URL;
  if (typeof navigator !== 'undefined') {
    // @ts-ignore Platform may not exist in some test envs
    const { Platform } = require('react-native');
    if (Platform?.OS === 'android') {
      return `https://ec79f7af9898.ngrok-free.app`; // Example: ngrok/https endpoint or use 127.0.0.1 with adb reverse
    }
  }
  return `http://localhost:${port}`;
};

export const OPENAI_REALTIME_MODEL = 'gpt-realtime';
export const DEFAULT_SYSTEM_INSTRUCTIONS =
  "You are a concise voice assistant. Always respond in the user's spoken language; if the language is unclear, default to English. Keep replies short.";
export const DEFAULT_VOICE = 'alloy';

// If your environment requires the client to create the DataChannel,
// set this to true. Default false to avoid crashes on some Android stacks.
export const CREATE_LOCAL_DATA_CHANNEL = true;

// Optional: add your own TURN for restrictive networks
// Example (Twilio Network Traversal, coturn, etc.)
export const ICE_SERVERS: RTCConfiguration['iceServers'] = [
  { urls: 'stun:stun.l.google.com:19302' },
  // {
  //   urls: [
  //     'turn:turn.your-domain.com:3478?transport=udp',
  //     'turn:turn.your-domain.com:3478?transport=tcp',
  //     'turns:turn.your-domain.com:5349?transport=tcp',
  //   ],
  //   username: 'TURN_USERNAME',
  //   credential: 'TURN_PASSWORD',
  // },
];
