import React, {useMemo, useRef, useState} from 'react';
import {StatusBar, StyleSheet, Text, TouchableOpacity, View, FlatList, Platform, PermissionsAndroid, ActivityIndicator} from 'react-native';
import { SafeAreaView, SafeAreaProvider } from 'react-native-safe-area-context';
import {RTCView} from 'react-native-webrtc';
import {OpenAIRealtimeClient, ChatMessage} from './src/realtime/OpenAIRealtimeClient';

function App(): React.JSX.Element {
  const [status, setStatus] = useState<'disconnected' | 'connecting' | 'connected' | 'error'>('disconnected');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [remoteStreamUrl, setRemoteStreamUrl] = useState<string | null>(null);
  const [micEnabled, setMicEnabled] = useState<boolean>(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const clientRef = useRef<OpenAIRealtimeClient | null>(null);

  const client = useMemo(() => {
    const c = new OpenAIRealtimeClient({
      onEvent: (ev) => {
        if (__DEV__) {
          try {
            // eslint-disable-next-line no-console
            console.log('oai-event:', ev?.type || ev);
          } catch {}
        }
      },
      onStateChange: (s) => setStatus(s),
      onMessage: (m) => {
        // Coalesce partials: replace last item if same role and id prefix
        setMessages(prev => {
          if (prev.length === 0) return [m];
          const last = prev[prev.length - 1];
          const isPartial = m.id.startsWith('a_') || m.id.startsWith('u_');
          if (isPartial && last.role === m.role) {
            const next = prev.slice(0, -1).concat(m);
            return next;
          }
          return prev.concat(m);
        });
      },
      onRemoteStream: (s) => {
        if (s) setRemoteStreamUrl(s.toURL());
        else setRemoteStreamUrl(null);
      },
    });
    clientRef.current = c;
    return c;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const connect = async () => {
    try {
      setErrorMsg(null);
      if (Platform.OS === 'android') {
        const granted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
          {
            title: 'Microphone Permission',
            message: 'We need access to your microphone to talk with the assistant.',
            buttonPositive: 'OK',
          },
        );
        if (granted !== PermissionsAndroid.RESULTS.GRANTED) {
          setStatus('error');
          setErrorMsg('Microphone permission denied.');
          return;
        }
      }
      await client.connect();
      // Start with mic off until user presses the button
      client.setMicEnabled(false);
      setMicEnabled(false);
    } catch (e) {
      setStatus('error');
      setErrorMsg((e as Error)?.message || 'Failed to connect');
    }
  };

  const disconnect = async () => {
    await client.disconnect();
    setMessages([]);
    setRemoteStreamUrl(null);
    setMicEnabled(false);
  };

  const handlePressIn = () => {
    client.setMicEnabled(true);
    setMicEnabled(true);
  };
  const handlePressOut = () => {
    client.setMicEnabled(false);
    setMicEnabled(false);
  };

  const renderItem = ({item}: {item: ChatMessage}) => (
    <View style={[styles.bubble, item.role === 'assistant' ? styles.assistant : styles.user]}>
      <Text style={styles.bubbleRole}>{item.role === 'assistant' ? 'Assistant' : 'You'}</Text>
      <Text style={styles.bubbleText}>{item.text}</Text>
    </View>
  );

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container} edges={['top','bottom','left','right']}>
      <StatusBar barStyle={'light-content'} />
      <View style={styles.header}>
        <View style={styles.headerLeft}>
          <View style={[styles.statusDot, status === 'connected' ? styles.dotOn : status === 'connecting' ? styles.dotConnecting : styles.dotOff]} />
          <Text style={styles.title}>Realtime Voice</Text>
        </View>
        <View style={styles.headerRight}>
          {status === 'connecting' && <ActivityIndicator color="#9fb0cf" size="small" />}
          {status !== 'connected' ? (
            <TouchableOpacity style={[styles.headerButton, styles.headerConnect]} onPress={connect}>
              <Text style={styles.headerButtonText}>Connect</Text>
            </TouchableOpacity>
          ) : (
            <TouchableOpacity style={[styles.headerButton, styles.headerEnd]} onPress={disconnect}>
              <Text style={styles.headerButtonText}>Disconnect</Text>
            </TouchableOpacity>
          )}
        </View>
      </View>

      {errorMsg ? (
        <View style={styles.errorBar}><Text style={styles.errorText}>{errorMsg}</Text></View>
      ) : null}

      {remoteStreamUrl ? (
        // Keep remote audio alive; RTCView renders nothing for audio but ensures stream is attached
        <RTCView streamURL={remoteStreamUrl} style={styles.hiddenAudio} />
      ) : null}

      <FlatList
        style={styles.list}
        data={messages}
        keyExtractor={(m) => m.id}
        renderItem={renderItem}
        contentContainerStyle={{padding: 16, paddingBottom: 140}}
      />

      {status === 'connected' ? (
        <View style={styles.pttWrap}>
          <TouchableOpacity
            activeOpacity={0.9}
            onPressIn={handlePressIn}
            onPressOut={handlePressOut}
            style={[styles.pttButtonBig, micEnabled ? styles.pttBigActive : undefined]}
          >
            <Text style={styles.pttBigText}>{micEnabled ? 'Listening…' : 'Hold to Talk'}</Text>
          </TouchableOpacity>
        </View>
      ) : null}

      <View style={styles.footerNote}>
        <Text style={styles.noteText}>
          {Platform.OS === 'android'
            ? 'Android: set server to 127.0.0.1 via adb reverse, or use your ngrok/LAN URL.'
            : 'iOS Simulator: uses localhost by default.'}
        </Text>
      </View>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0b0d12' },
  header: { paddingHorizontal: 16, paddingVertical: 12, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  headerLeft: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  headerRight: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  statusDot: { width: 10, height: 10, borderRadius: 999, backgroundColor: '#394457' },
  dotOn: { backgroundColor: '#22c55e' },
  dotConnecting: { backgroundColor: '#eab308' },
  dotOff: { backgroundColor: '#ef4444' },
  title: { color: 'white', fontSize: 18, fontWeight: '600' },
  headerButton: { paddingHorizontal: 12, paddingVertical: 8, borderRadius: 10 },
  headerConnect: { backgroundColor: '#2dd4bf' },
  headerEnd: { backgroundColor: '#ef4444' },
  headerButtonText: { color: '#0b0d12', fontWeight: '700' },
  hiddenAudio: { width: 1, height: 1, opacity: 0 },
  errorBar: { backgroundColor: '#7f1d1d', paddingVertical: 8, paddingHorizontal: 16 },
  errorText: { color: '#fecaca', textAlign: 'center' },
  list: { flex: 1 },
  bubble: { padding: 14, marginVertical: 6, borderRadius: 14, maxWidth: '86%', shadowColor: '#000', shadowOpacity: 0.2, shadowRadius: 8, shadowOffset: { width: 0, height: 4 }, elevation: 4 },
  assistant: { backgroundColor: 'rgba(255,255,255,0.06)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)', alignSelf: 'flex-start' },
  user: { backgroundColor: 'rgba(59,130,246,0.15)', borderWidth: 1, borderColor: 'rgba(59,130,246,0.25)', alignSelf: 'flex-end' },
  bubbleRole: { color: '#9fb0cf', fontSize: 12, marginBottom: 4 },
  bubbleText: { color: '#e6ecf8', fontSize: 16 },
  pttWrap: { position: 'absolute', bottom: 32, left: 0, right: 0, alignItems: 'center', justifyContent: 'center' },
  footerNote: { paddingHorizontal: 16, paddingBottom: 12, position: 'absolute', bottom: 6, left: 0, right: 0 },
  noteText: { color: '#6b7a99', fontSize: 12, textAlign: 'center' },
  pttButtonBig: { width: 200, height: 200, borderRadius: 100, backgroundColor: '#2563eb', alignItems: 'center', justifyContent: 'center', borderWidth: 10, borderColor: 'rgba(255,255,255,0.08)' },
  pttBigActive: { backgroundColor: '#22c55e' },
  pttBigText: { color: 'white', fontWeight: '800', fontSize: 18 },
});

export default App;
