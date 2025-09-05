import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import fetch from 'node-fetch';

const app = express();
app.use(cors()); // tighten for prod

const PORT = process.env.PORT || 8787;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const MODEL = process.env.REALTIME_MODEL || 'gpt-realtime';
const VOICE = process.env.REALTIME_VOICE || 'alloy';
const INSTRUCTIONS =
  process.env.REALTIME_INSTRUCTIONS ||
  'You are a concise voice assistant. Always respond in the user\'s spoken language; if unclear, default to English. Keep replies short.';

if (!OPENAI_API_KEY) {
  console.error('Missing OPENAI_API_KEY in .env');
  process.exit(1);
}

app.get('/session', async (req, res) => {
  try {
    const r = await fetch('https://api.openai.com/v1/realtime/sessions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
        'OpenAI-Beta': 'realtime=v1',
      },
      body: JSON.stringify({
        model: MODEL,
        voice: VOICE,
        instructions: INSTRUCTIONS,
        modalities: ["text", "audio"],
        turn_detection: { type: 'server_vad' },
      }),
    });
    const data = await r.json();
    if (!r.ok) {
      console.error('OpenAI session error:', data);
      return res.status(r.status).json(data);
    }
    res.json(data);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to create session' });
  }
});

app.listen(PORT, () => {
  console.log(`Realtime ephemeral server listening on :${PORT}`);
});
