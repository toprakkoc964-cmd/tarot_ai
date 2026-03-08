# Tarot AI

Flutter + Firebase project scaffold for Tarot AI V1.

## Modules
- `functions/`: Firebase Cloud Functions (TypeScript)
- `flutter_app/`: Flutter client scaffold

## Quick Start
1. Configure Firebase projects: `dev` and `prod`.
2. In `functions/` run `npm install && npm run build`.
3. In `flutter_app/` run `flutter pub get`.
4. Set Firebase options and deploy rules/functions.

## Env Variables (Functions)
- `OPENAI_API_KEY`
- `OPENAI_MODEL` (default `gpt-4o-mini`)
- `OPENAI_TEMPERATURE`
- `ELEVENLABS_API_KEY`
- `ELEVENLABS_VOICE_ID`
- `ELEVENLABS_MODEL_ID`
- `INITIAL_FREE_CREDITS`
- `CONSENT_VERSION`
- `APP_CHECK_ENFORCE`
- `APP_DEEP_LINK_BASE`
- `APP_STORE_URL`
- `DEFAULT_PERSONA_ID`
- `DAILY_NUDGE_TIMEZONE`
- `DAILY_NUDGE_DEEP_LINK`
- `SHARE_FONT_PATH` (optional)

## Firestore Collections
- `users/{uid}`
- `users/{uid}/readings/{readingId}`
- `users/{uid}/credit_ledger/{txId}`
- `users/{uid}/iap_transactions/{transactionId}`
- `users/{uid}/fcm_tokens/{token}`
- `ai_personas/{personaId}`
