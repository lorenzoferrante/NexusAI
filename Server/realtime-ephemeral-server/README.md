Realtime Ephemeral Session Server
=================================

Purpose
- Issues short-lived OpenAI Realtime session tokens that your iOS app uses to connect directly to `gpt-realtime` over WebSocket/WebRTC.
- Keeps your real OpenAI API key on the server — never ship it in the app.

Quick Start (Node + Express)
- Create `.env` with `OPENAI_API_KEY=sk-...`
- Run: `npm i` then `npm start`
- Default route: `GET /session` returns a JSON payload with `client_secret.value` — use that as the Bearer token on the client.

Security Notes
- Lock down CORS to your app domain(s) in production.
- Tokens expire quickly; request a fresh one per connection.

