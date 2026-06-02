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

## Auth Provider Setup (Madde 1)
Firebase Console'da `Authentication > Sign-in method` altinda su provider'lari ac:
- `Email/Password`
- `Google`
- `Apple`

### Android
- `Project settings > Your apps > Android` altinda SHA-1 ve SHA-256 fingerprint ekle.
- `google-services.json` dosyasini `android/app/google-services.json` altina koy.
- **Google ile giris** icin `oauth_client` dizisi bos olmamali. Bos ise:
  1. Firebase Console → Authentication → Sign-in method → **Google** acik olsun.
  2. Android uygulamasina debug SHA-1/SHA-256 ekle (`powershell scripts/print_android_sha.ps1`).
  3. Guncel `google-services.json` indir ve `android/app/` altina kopyala.
  4. Firebase → Authentication → Google → **Web client ID** degerini `lib/src/core/google_auth_config.dart` icindeki `_defaultWebClientId` alanina yapistir (veya `--dart-define=GOOGLE_WEB_CLIENT_ID=...` kullan).

Debug SHA-1 (bu makine): `B5:41:CC:EB:BF:1C:13:87:90:52:EA:CB:6E:B8:7B:33:EA:70:34:81`

### Tarot kart gorselleri (yerel asset)
Major Arcana gorselleri `assets/card-images/` klasorunden yuklenir (`pubspec.yaml` assets).
Ornek dosya adlari: `00_the_fool.webp`, `20_judgement.webp`, `21_the_world.webp` (22 dosya).
Dosya eksik veya adi hataliysa kart yine secilir; gorsel yerine placeholder gosterilir.

### iOS (Apple Sign-In)
- Apple Developer hesabinda `Sign in with Apple` capability acik olmali.
- Firebase iOS app ayarlarinda dogru `Bundle ID` kullan.
- Xcode tarafinda `Runner` target icin `Sign In with Apple` capability ekli olmali.

### Flutter tarafi
- `AuthService` artik su metotlari destekliyor:
  - `signInWithGoogle()`
  - `signInWithApple()`
- Login ekraninda Apple/Google butonlari backend auth akisina baglandi.

## Env Variables (Functions)
- `GEMINI_API_KEY`
- `GEMINI_MODEL` (default `gemini-2.5-flash`)
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
