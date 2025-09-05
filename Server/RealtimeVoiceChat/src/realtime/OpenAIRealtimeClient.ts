import {MediaStream, mediaDevices, RTCPeerConnection, RTCIceCandidateType, RTCSessionDescription, RTCSessionDescriptionType} from 'react-native-webrtc';
import {CREATE_LOCAL_DATA_CHANNEL, DEFAULT_SYSTEM_INSTRUCTIONS, DEFAULT_VOICE, OPENAI_REALTIME_MODEL, getEphemeralServerBaseURL, ICE_SERVERS} from '../config';

export type ChatMessage = {
  id: string;
  role: 'user' | 'assistant' | 'system';
  text: string;
};

type EventHandler = (event: any) => void;
type MessageHandler = (message: ChatMessage) => void;
type StreamHandler = (stream: MediaStream | null) => void;
type StateHandler = (state: 'disconnected' | 'connecting' | 'connected' | 'error') => void;

export class OpenAIRealtimeClient {
  pc: RTCPeerConnection | null = null;
  dc: RTCDataChannel | null = null;
  localStream: MediaStream | null = null;
  remoteStream: MediaStream | null = null;
  onEvent?: EventHandler;
  onMessage?: MessageHandler;
  onRemoteStream?: StreamHandler;
  onStateChange?: StateHandler;
  private userPartial: string = '';
  private assistantPartial: string = '';

  constructor(handlers?: {
    onEvent?: EventHandler;
    onMessage?: MessageHandler;
    onRemoteStream?: StreamHandler;
    onStateChange?: StateHandler;
  }) {
    this.onEvent = handlers?.onEvent;
    this.onMessage = handlers?.onMessage;
    this.onRemoteStream = handlers?.onRemoteStream;
    this.onStateChange = handlers?.onStateChange;
  }

  private setState(state: 'disconnected' | 'connecting' | 'connected' | 'error') {
    this.onStateChange?.(state);
  }

  async connect(): Promise<void> {
    if (this.pc) {
      await this.disconnect();
    }
    this.setState('connecting');

    if (__DEV__) console.log('realtime: connect() begin');
    const token = await this.fetchEphemeralToken();
    if (!token) {
      this.setState('error');
      throw new Error('Failed to get ephemeral token');
    }
    if (__DEV__) console.log('realtime: got ephemeral token');

    // Create RTCPeerConnection
    this.pc = new RTCPeerConnection({ iceServers: ICE_SERVERS || [{ urls: 'stun:stun.l.google.com:19302' }] });

    // Surface connection state transitions
    this.pc.onconnectionstatechange = () => {
      const s = this.pc?.connectionState;
      if (s === 'connected') this.setState('connected');
      if (s === 'failed' || s === 'disconnected') this.setState('error');
      if (__DEV__) console.log('realtime: connectionState', s);
    };
    this.pc.oniceconnectionstatechange = () => {
      const s = this.pc?.iceConnectionState;
      if (s === 'connected' || s === 'completed') this.setState('connected');
      if (s === 'failed' || s === 'disconnected') this.setState('error');
      if (__DEV__) console.log('realtime: iceConnectionState', s);
    };
    // @ts-ignore addEventListener exists in RN-WebRTC
    this.pc.addEventListener?.('icegatheringstatechange', () => {
      if (__DEV__) console.log('realtime: iceGatheringState', this.pc?.iceGatheringState);
    });
    // @ts-ignore addEventListener exists in RN-WebRTC
    this.pc.addEventListener?.('icecandidate', () => {
      if (__DEV__) console.log('realtime: icecandidate');
    });

    // Handle remote stream
    this.remoteStream = new MediaStream();
    this.pc.ontrack = (event) => {
      // Attach each incoming track to our remote stream
      // @ts-ignore - event.streams[0] is available in react-native-webrtc
      const [stream] = event.streams;
      if (stream) {
        this.remoteStream = stream;
        this.onRemoteStream?.(this.remoteStream);
      } else if (event.track) {
        this.remoteStream?.addTrack(event.track);
        this.onRemoteStream?.(this.remoteStream);
      }
      if (__DEV__) console.log('realtime: ontrack');
    };

    // DataChannel: attach to either client-created or server-created channel
    const attachDC = (dc: RTCDataChannel) => {
      this.dc = dc as any;
      this.dc.onopen = () => {
        this.sendEvent({
          type: 'session.update',
          session: {
            instructions: DEFAULT_SYSTEM_INSTRUCTIONS,
            voice: DEFAULT_VOICE,
            modalities: ['text', 'audio'],
            turn_detection: { type: 'server_vad' },
          },
        });
      };
      this.dc.onmessage = (e: any) => this.handleEventMessage(e.data);
      this.dc.onerror = () => this.setState('error');
    };

    // Prefer server-created datachannel; optionally create locally via config
    this.pc.ondatachannel = (e: any) => {
      if (e?.channel?.label === 'oai-events') attachDC(e.channel);
    };
    if (CREATE_LOCAL_DATA_CHANNEL) {
      try {
        // @ts-ignore createDataChannel signature
        const localDC = this.pc.createDataChannel('oai-events', { ordered: true });
        attachDC(localDC);
      } catch {}
    }

    // Mic stream
    this.localStream = await mediaDevices.getUserMedia({
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
      },
    });
    this.localStream.getTracks().forEach((track) => {
      this.pc?.addTrack(track, this.localStream!);
    });

    // Avoid addTransceiver for wider Android compatibility; addTrack already added mic

    const offer = await this.pc.createOffer();
    await this.pc.setLocalDescription(offer);

    // Wait for ICE gathering to complete (non-trickle HTTP SDP)
    await new Promise<void>((resolve) => {
      if (!this.pc) return resolve();
      if (this.pc.iceGatheringState === 'complete') return resolve();
      const timeout = setTimeout(() => resolve(), 8000);
      const check = () => {
        if (this.pc?.iceGatheringState === 'complete') {
          clearTimeout(timeout);
          this.pc?.removeEventListener?.('icegatheringstatechange', check as any);
          resolve();
        }
      };
      // @ts-ignore RN-WebRTC supports addEventListener
      this.pc.addEventListener?.('icegatheringstatechange', check);
    });

    // Exchange SDP with OpenAI Realtime via HTTP POST (using ephemeral token)
    const base = 'https://api.openai.com/v1/realtime';
    const url = `${base}?model=${encodeURIComponent(OPENAI_REALTIME_MODEL)}`;
    if (__DEV__) console.log('realtime: posting offer to', url);
    const r = await this.fetchWithTimeout(url, 60000, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/sdp',
        'OpenAI-Beta': 'realtime=v1',
        Accept: 'application/sdp',
      },
      body: offer.sdp || '',
    });
    const answerSDP = await r.text();
    if (!r.ok) {
      this.setState('error');
      throw new Error(`SDP exchange failed: ${answerSDP}`);
    }

    const remoteDesc: RTCSessionDescriptionType = {
      type: 'answer',
      sdp: answerSDP,
    };
    await this.pc.setRemoteDescription(new RTCSessionDescription(remoteDesc));
    if (__DEV__) console.log('realtime: setRemoteDescription OK');

    this.setState('connected');
  }

  async disconnect(): Promise<void> {
    try {
      if (this.dc) {
        this.dc.close();
        this.dc = null;
      }
      if (this.pc) {
        this.pc.close();
        this.pc = null;
      }
      if (this.localStream) {
        this.localStream.getTracks().forEach((t) => t.stop());
        this.localStream = null;
      }
      if (this.remoteStream) {
        this.remoteStream.getTracks().forEach((t) => t.stop());
        this.remoteStream = null;
      }
    } finally {
      this.setState('disconnected');
    }
  }

  // Push-to-talk: enable/disable mic track
  setMicEnabled(enabled: boolean) {
    this.localStream?.getAudioTracks().forEach((t) => {
      // Only toggle enabled to keep track attached for VAD
      t.enabled = enabled;
    });
  }

  private async fetchEphemeralToken(): Promise<string | null> {
    try {
      const url = `${getEphemeralServerBaseURL()}/session`;
      if (__DEV__) console.log('realtime: fetching ephemeral token from', url);
      const r = await this.fetchWithTimeout(url, 10000, {
        headers: { 'ngrok-skip-browser-warning': '1' },
      });
      if (!r.ok) return null;
      const data = await r.json();
      const token = data?.client_secret?.value;
      return token || null;
    } catch (e) {
      return null;
    }
  }

  private async fetchWithTimeout(resource: string, timeoutMs = 15000, init?: RequestInit): Promise<Response> {
    const ctrl = new AbortController();
    const id = setTimeout(() => ctrl.abort(), timeoutMs);
    try {
      // @ts-ignore RN fetch supports signal
      const res = await fetch(resource, { ...(init || {}), signal: ctrl.signal });
      return res as Response;
    } finally {
      clearTimeout(id);
    }
  }

  private emitMessage(msg: ChatMessage) {
    this.onMessage?.(msg);
  }

  private handleEventMessage(raw: any) {
    try {
      const event = typeof raw === 'string' ? JSON.parse(raw) : raw;
      this.onEvent?.(event);

      switch (event.type) {
        // Assistant text streaming
        case 'response.output_text.delta': {
          const chunk = event.delta as string;
          this.assistantPartial += chunk;
          this.emitMessage({ id: `a_${Date.now()}`, role: 'assistant', text: this.assistantPartial });
          break;
        }
        case 'response.completed': {
          // Finalize assistant message
          if (this.assistantPartial) {
            this.emitMessage({ id: `a_final_${Date.now()}`, role: 'assistant', text: this.assistantPartial });
            this.assistantPartial = '';
          }
          break;
        }

        // Optional: user transcript events if provided by server
        case 'input_audio_transcription.delta': {
          const chunk = event.delta as string;
          this.userPartial += chunk;
          this.emitMessage({ id: `u_${Date.now()}`, role: 'user', text: this.userPartial });
          break;
        }
        case 'input_audio_transcription.completed': {
          if (this.userPartial) {
            this.emitMessage({ id: `u_final_${Date.now()}`, role: 'user', text: this.userPartial });
            this.userPartial = '';
          }
          break;
        }
        default:
          break;
      }
    } catch (e) {
      // ignore parse errors
    }
  }

  sendEvent(obj: any) {
    if (!this.dc || this.dc.readyState !== 'open') return;
    try {
      this.dc.send(JSON.stringify(obj));
    } catch {}
  }
}
