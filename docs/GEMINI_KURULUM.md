# Bilge Aris — Gemini API anahtarı

Aris yorumları **Firebase Cloud Functions** üzerinden çalışır. Anahtar uygulama içine (APK) konmaz; sadece sunucu tarafında tutulur.

## 1. API anahtarını al

1. [Google AI Studio](https://aistudio.google.com/apikey) → **Create API key**
2. Anahtarı kopyala (`AIza...` ile başlar)

## 2. Yerel geliştirme — anahtarı yapıştıracağın dosya

Proje kökünde:

```
functions/.env
```

Bu dosya **git’e girmez** (`.gitignore` içinde). Şablon:

```bash
cd functions
copy .env.example .env
```

`functions/.env` içinde şu satırı doldur:

```env
GEMINI_API_KEY=AIzaSy...BURAYA_YAPIŞTIR
```

İsteğe bağlı modeller (varsayılanlar genelde yeterli):

```env
GEMINI_ARIS_MODEL=gemini-2.5-flash-lite
GEMINI_MODEL=gemini-2.5-flash
```

Emülatör veya `npm run serve` ile test ederken bu `.env` dosyası okunur.

## 3. Canlı (production) — Firebase Secret

Deploy edilen fonksiyonlar `.env` dosyasını **taşımaz**. Canlıda secret kullanılır:

```powershell
cd functions
firebase functions:secrets:set GEMINI_API_KEY
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
| `functions/.env` içinde `GEMINI_API_KEY` boş | Anahtarı yapıştır, `npm run build`, deploy |
| Fonksiyon hiç deploy edilmemiş | `firebase deploy --only functions` |
| Oturum / profil | Giriş yap, Firestore’da `users/{uid}` kaydı olsun |
| Emülatör kullanıyorsan | `functions/.env` + emülatörün functions’ı gördüğünden emin ol |

Uygulama içinde API anahtarı **tutulmaz**; sadece `functions/.env` ve Firebase Secret.
