# Bilge Aris — Gemini API anahtarı

Aris yorumları **Firebase Cloud Functions** üzerinden çalışır. Anahtar uygulama içine (APK) konmaz; sadece sunucu tarafında tutulur.

## 1. API anahtarını al

1. [Google AI Studio](https://aistudio.google.com/apikey) → **Create API key**
2. Anahtarı kopyala (`AIza...` ile başlar)

## 2. Yerel geliştirme — gizli anahtar tutma

Gemini API anahtarını yerelde `.env`, Dart, Swift, JSON veya başka bir dosyada tutma. Yerel dosyalar yalnızca gizli olmayan çalışma ayarları için kullanılabilir:

```env
GEMINI_ARIS_MODEL=gemini-2.5-flash-lite
GEMINI_MODEL=gemini-2.5-flash-lite
```

Canlı AI çağrıları Firebase Secret üzerinden çalışır. Lokal emülatörde gerçek Gemini çağrısı gerekiyorsa geçici bir terminal ortam değişkeni kullan ve oturum bitince kapat; repo dosyasına yazma.

## 3. Canlı (production) — Firebase Secret

Deploy edilen fonksiyonlar `.env` dosyasını **taşımaz**. Canlıda secret kullanılır:

```powershell
firebase functions:secrets:set GEMINI_API_KEY --project tarot-ai-dev-8f9a0
```

İstendiğinde anahtarı yapıştır. Ardından fonksiyonları yeniden deploy et:

```powershell
firebase deploy --only functions:generateArisOpeningReading,functions:continueArisConversation,functions:analyzePalmReading
```

veya tüm functions:

```powershell
firebase deploy --only functions
```

## 4. Davranış (guardrails)

- Açılış ve sohbet yalnızca **seçilen kart(lar)** üzerinden yorumlanır; genel burç / boş metin üretilmez.
- Hava durumu, kod, siyaset, tarif vb. **konu dışı** sorularda jeton düşülmeden kısa red mesajı döner.
- Ölüm tarihi, tedavi, hukuk/finans kararı, intihar vb. **hassas** konularda sabit güvenlik metni kullanılır (Gemini’ye gitmez).
- Gemini hata verirse veya anahtar yoksa, yine de **kart isimlerine dayalı** kısa fallback metin döner (ekran tamamen boş kalmaz).

## 5. Hata: “Aris şu an yanıt veremiyor”

Sırayla kontrol et:

| Mesaj / durum | Çözüm |
|---------------|--------|
| `GEMINI_API_KEY_MISSING` | Firebase Secret tanımlı mı kontrol et: `firebase functions:secrets:access GEMINI_API_KEY --project tarot-ai-dev-8f9a0` |
| Fonksiyon hiç deploy edilmemiş | `firebase deploy --only functions` |
| Oturum / profil | Giriş yap, Firestore’da `users/{uid}` kaydı olsun |
| Emülatör kullanıyorsan | Gerçek anahtarı repo dosyasına yazma; geçici shell env kullan |

Uygulama içinde ve yerel repo dosyalarında API anahtarı **tutulmaz**; canlı ortamda yalnızca Firebase Secret kullanılır.
