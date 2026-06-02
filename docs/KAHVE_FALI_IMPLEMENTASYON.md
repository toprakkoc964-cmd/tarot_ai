# Kahve Falı — Uygulama Dokümantasyonu

Bu doküman, Tarot AI uygulamasına gönderilen **Kahve Falı (Coffee Reading)** spesifikasyon prompt’undan sonra yapılan tüm geliştirmeleri, mimari kararları ve operasyonel detayları açıklar.

**Proje:** `tarot_ai`
**Firebase projesi:** `tarot-ai-dev-8f9a0`
**Tarih:** Mayıs 2026

---

## 1. Özet

Kahve Falı özelliği **gated single-pass validation + reading** mimarisine taşındı:

1. Kullanıcı 3 fotoğraf yükler (fincan içi, tabak, dış görünüm).
2. Her fotoğraf **cihazda** doğrulanır (ML Kit + heuristikler).
3. 3 fotoğraf geçince kullanıcı `Madam Aris’e Yorumlat · 20 Jeton` CTA’sı ile açıkça onay verir.
4. Onaydan sonra fotoğraflar **Firebase Storage**’a yüklenir.
5. **Cloud Function** (`analyzeCoffeeReading`) Gemini Vision ile tek çağrıda hem doğrulama hem fal yorumu üretir.
6. AI doğrulaması başarılıysa **20 jeton düşülür**; başarısızsa rezervasyon serbest bırakılır ve `reading: null` döner.

**Kritik güvenlik kuralı:** Gemini / OpenAI API anahtarı Flutter uygulamasında **bulunmaz**. Tüm AI işlemi backend üzerinden yapılır.

---

## 2. Kullanıcı Akışı

```
Kozmik sekmesi
  → "Kahve Falını Başlat"
  → CoffeeCaptureFlowScreen (3 adımlı fotoğraf akışı)
      Adım 1: cupInside   — Fincanın içi / telve
      Adım 2: saucer      — Fincan tabağı
      Adım 3: cupSide     — Fincanın dış / yan görünümü
  → Her adım: Kamera veya Galeri
  → Pick → Crop → Compress → Lokal validation
  → 3 fotoğraf tamamlanınca kullanıcı onayı:
      "Madam Aris’e Yorumlat · 20 Jeton"
  → Kullanıcı CTA'ya dokununca:
      "Madam Aris telvedeki sembolleri çözümlüyor..."
  → Backend AI (analyzeCoffeeReading)
  → Başarılı: CoffeeResultScreen (Madam Aris yorumu)
  → Başarısız: Hata dialogu, jeton düşmez
```

### UI metinleri (AppTexts)

| Key | TR örneği |
|-----|-----------|
| `coffeeTitle` | Kahve Falı |
| `coffeeDescription` | Madam Aris fincanın içini, tabağını ve dış görünümünü birlikte yorumlayacak. |
| `coffeePreparingPhoto` | Fotoğraf hazırlanıyor... |
| `coffeeValidatingPhoto` | Fotoğraf doğrulanıyor... |
| `coffeeAnalyzingSymbols` | Madam Aris telvedeki sembolleri çözümlüyor... |
| `coffeeValidationCameraRecommended` | En doğru kahve falı için fincanını doğrudan kamerayla çekmeni öneririz. |

Gizlilik metinleri ekranda gösterilir:

- `coffeeValidationPrivacyInfo`
- `coffeeValidationLocalInfo` (cihazda ilk doğrulama)
- `coffeeValidationBackendInfo` (analiz servisine güvenli gönderim)

---

## 3. Fotoğraf Pipeline (Flutter)

Dosya: `lib/src/features/coffee_reading/services/coffee_image_pipeline_service.dart`

### 3.1 Image Picker

| Parametre | Değer |
|-----------|-------|
| `maxWidth` | 1600 px |
| `maxHeight` | 1600 px |
| `imageQuality` | 90 |
| `requestFullMetadata` | Kamera: `true`, Galeri: picker varsayılanı |

Kaynak: `ImageSource.camera` veya `ImageSource.gallery`

### 3.2 Crop (Image Cropper)

| Kural | Değer |
|-------|-------|
| En-boy oranı | **1:1 (kare) zorunlu** |
| `lockAspectRatio` | `true` |
| `aspectRatioPresets` | Sadece `square` |
| Tema | Dark / mor-pembe (`AppColors`) |
| iOS | `aspectRatioLockEnabled: true`, ratio picker gizli |

Adıma özel crop başlıkları:

- `coffeeCropInsideTitle` — Fincanın İçini Ortala
- `coffeeCropSaucerTitle` — Tabağı Ortala
- `coffeeCropCupSideTitle` — Fincanın Dışını Ortala

### 3.3 Compress (flutter_image_compress)

| Parametre | Değer |
|-----------|-------|
| Format | **JPEG** |
| `quality` | **80** |
| `minWidth` / `minHeight` | **1024** px |
| `keepExif` | `false` (gizlilik + stock risk azaltma) |
| Hedef boyut | ~**500 KB** civarı (quality 80 + 1024 min ile pratikte) |
| Dosya adı | `coffee_{step}_{timestamp}.jpg` |

Örnek: `coffee_cupInside_1716645123456789.jpg`

### 3.4 Temp dosya temizliği

- **Galeri orijinali asla silinmez.**
- Sadece uygulamanın oluşturduğu temp dosyalar temizlenir (crop, compress, iptal, invalid).
- Servis: `coffee_temp_file_cleaner.dart`
- Flow terk edilirse / dispose olursa `CoffeeCaptureFlowScreen` temp cleanup yapar.
- Upload tamamlanıp sonuç alındığında lokal JPEG dosyaları temizlenir.

---

## 4. Firebase Storage — 5 MB Limit

Dosya: `storage.rules`

Kahve falı fotoğrafları şu path’e yüklenir:

```
coffee/{uid}/{uploadId}/cupInside.jpg
coffee/{uid}/{uploadId}/saucer.jpg
coffee/{uid}/{uploadId}/cupSide.jpg
```

### Storage güvenlik kuralları

```javascript
match /coffee/{uid}/{uploadId}/{fileName} {
  allow create: if request.auth != null
    && request.auth.uid == uid
    && uploadId.matches('coffee_[0-9]+')
    && fileName.matches('(cupInside|saucer|cupSide)\\.jpg')
    && request.resource != null
    && request.resource.contentType == 'image/jpeg'
    && request.resource.size <= 5 * 1024 * 1024;
  allow delete: if request.auth != null && request.auth.uid == uid;
  allow read, update: if false;
}
```

| Kural | Açıklama |
|-------|----------|
| Kim yükleyebilir | Sadece giriş yapmış kullanıcı, kendi `uid` path’ine |
| Kim okuyabilir | Client okuyamaz; analiz yalnız backend Admin SDK ile yapılır |
| Content-Type | Sadece `image/jpeg` |
| **Maksimum dosya boyutu** | **5 MB** (`5 * 1024 * 1024` byte) |
| Upload tarafı | `CoffeeBackendService` → `FirebaseStorage.putFile` |

> **Not:** Client tarafında compress (~500 KB hedef) + Storage kuralı (5 MB hard limit) birlikte çalışır. Compress başarısız olursa veya dosya şişerse Storage upload reddedilir.

---

## 5. Lokal Doğrulama Katmanları

Orchestrator: `coffee_validation_service.dart`

Her fotoğraf için sırayla:

### 5.1 ML Kit Label Validation

- Paket: `google_mlkit_image_labeling`
- `InputImage.fromFile`
- Adıma özel strong / weak label setleri
- Sadece "cup" label’ı yetmez; step match + residue skoru düşükse **invalid**

### 5.2 Görsel Kalite (`coffee_image_quality_service.dart`)

128×128 grayscale üzerinde:

| Metrik | Eşik | Failure reason |
|--------|------|----------------|
| Laplacian variance (blur) | `< 18` | `imageTooBlurry` |
| Ortalama luminance (karanlık) | `< 0.18` | `imageTooDark` |
| Ortalama luminance (parlak) | `> 0.88` | `imageTooBright` |

### 5.3 Telve / Kahve İzi Heuristiği (`coffee_residue_detection_service.dart`)

96×96 resize, merkez ağırlıklı dairesel ROI, koyu kahverengi/siyah piksel oranı + texture variance:

| Adım | `darkResidueRatio` eşiği |
|------|--------------------------|
| `cupInside` | ≥ **0.03** + texture variance ≥ 120 |
| `saucer` | ≥ **0.015** veya coffee label / texture sinyali |

Boş/temiz fincan → `emptyCup` veya `noCoffeeResidueDetected`

### 5.4 Duplicate / Benzerlik (`coffee_image_similarity_service.dart`)

- Average hash (8×8 grayscale)
- Önceki adımlarla **≥ %85** benzerlik → `duplicateImage`
- Aynı görselin 3 adımda kullanılması engellenir

### 5.5 Screenshot / Stock Risk (`coffee_screenshot_risk_service.dart`)

Risk sinyalleri: screenshot, text, poster, logo label’ları; kırpma öncesi kaynak aspect ratio; EXIF metadata varlığı; galeri kaynağı bonus risk.

- Risk skoru ≥ **0.55** → `screenshotOrStockLike`

### 5.6 Screen Spoofing (`coffee_screen_spoofing_risk_service.dart`)

Moire benzeri pattern, ekran/cihaz label’ları, kenar uniformity.

- Risk skoru ≥ **0.62** → `screenSpoofing`

### 5.7 Uygunsuz İçerik

ML Kit label’ları: nudity, weapon, violence, id card vb. (confidence ≥ 0.55) → `inappropriateContent`

### 5.8 Composite Validation Score

```
coffeeValidationScore =
  objectLabelScore   × 0.25 +
  stepMatchScore     × 0.25 +
  residueTextureScore× 0.20 +
  imageQualityScore  × 0.15 +
  uniquenessScore    × 0.10 +
  sourceTrustScore   × 0.05
```

| Kaynak | Minimum skor |
|--------|----------------|
| Kamera | **≥ 0.70** |
| Galeri | **≥ 0.78** (daha sıkı) |
| Screenshot risk yüksek | **≥ 0.85** (strict mode) |

Lokal validation **başarısızsa backend’e gönderilmez.** Bu heuristikler kesin sahtecilik tespiti değildir; nihai gate backend AI doğrulamasıdır.

---

## 6. Modeller

| Dosya | Açıklama |
|-------|----------|
| `coffee_photo_step.dart` | `cupInside`, `saucer`, `cupSide` enum |
| `coffee_validation_failure_reason.dart` | 14 failure reason + backend mapping |
| `coffee_validation_result.dart` | Lokal validation sonucu (skor, flags, labels) |
| `coffee_image_pipeline_result.dart` | Compress edilmiş dosya + fingerprint + validation |
| `coffee_photo_bundle.dart` | 3 fotoğraf bundle helper |
| `coffee_ai_validation_response.dart` | Backend AI validation parse |
| `coffee_ai_reading_response.dart` | Madam Aris reading alanları |
| `coffee_analyze_response.dart` | Callable tam response |
| `coffee_reading_result.dart` | UI result wrapper |

### Reading alanları (AI başarılıysa)

- `generalEnergy` — Genel enerji
- `symbols` — Telvedeki semboller
- `saucerSigns` — Tabak izleri
- `outerCupMessage` — Dış fincan mesajı
- `pastTrace` — Geçmiş iz
- `presentMood` — Şu anki ruh hali
- `nearFutureMessage` — Yakın dönem
- `advice` — Madam Aris tavsiyesi
- `disclaimer` — Eğlence / farkındalık uyarısı

---

## 7. Backend — Gated Single-Pass

### 7.1 Cloud Function

**Ad:** `analyzeCoffeeReading`
**Dosya:** `functions/src/index.ts`
**Bölge:** `us-central1`
**Secret:** `GEMINI_API_KEY`

### 7.2 AI modülü

**Dosya:** `functions/src/lib/coffee-reading.ts`

- Model: `GEMINI_COFFEE_MODEL` veya varsayılan `gemini-2.5-flash-lite`
- `responseMimeType: application/json`
- Gerçek `responseSchema` ile structured output
- `maxOutputTokens: 1800`
- Tek çağrıda: 3 görsel (base64) + validation + reading

### 7.3 Strict JSON kuralları

Parser (`parseCoffeeAiPayload`):

- `validation.isValid == false` → `reading` **null olmalı**
- `validation.isValid == true` → dokuz reading alanının tamamı dolu string olmalı
- Markdown fence varsa strip edilir (fallback)
- Schema ihlali → hata, jeton düşülmez

### 7.4 Callable request (Flutter → Backend)

```json
{
  "languageCode": "tr",
  "imageRefs": {
    "cupInside": "coffee/{uid}/{uploadId}/cupInside.jpg",
    "saucer": "coffee/{uid}/{uploadId}/saucer.jpg",
    "cupSide": "coffee/{uid}/{uploadId}/cupSide.jpg"
  },
  "localValidation": {
    "cupInside": { "...CoffeeValidationResult.toBackendSummaryMap()" },
    "saucer": { "..." },
    "cupSide": { "..." }
  },
  "idempotencyKey": "idem_..."
}
```

### 7.5 Callable response

**Başarılı:**

```json
{
  "success": true,
  "chargedCredits": 20,
  "remainingCredits": 100,
  "readingId": "abc123",
  "validation": { "isValid": true, "..." },
  "reading": { "generalEnergy": "...", "..." }
}
```

**Başarısız validation:**

```json
{
  "success": false,
  "chargedCredits": 0,
  "remainingCredits": 120,
  "readingId": "",
  "validation": { "isValid": false, "userMessage": "..." },
  "reading": null
}
```

---

## 8. Cloud Functions’da Ne Depolanır?

> **Önemli:** Cloud Functions kendi içinde kalıcı veri tutmaz (stateless). Depolama Firebase servislerindedir.

### 8.1 Firebase Storage (fotoğraflar)

| Path | İçerik | Limit |
|------|--------|-------|
| `coffee/{uid}/{uploadId}/cupInside.jpg` | Fincan içi JPEG | max **5 MB** |
| `coffee/{uid}/{uploadId}/saucer.jpg` | Tabak JPEG | max **5 MB** |
| `coffee/{uid}/{uploadId}/cupSide.jpg` | Dış görünüm JPEG | max **5 MB** |

Upload: Flutter `CoffeeBackendService`
Download: Cloud Function (Gemini’ye base64 olarak gönderilir)

### 8.2 Firestore

| Collection / Doc | Ne zaman yazılır | İçerik |
|------------------|------------------|--------|
| `users/{uid}/coffee_readings/{id}` | AI validation **başarılı** | `imageRefs`, `validation`, `reading`, `languageCode`, `status: succeeded` |
| `users/{uid}/wallet.coffeeReservedCredits` | Analiz başlarken / biterken | Eş zamanlı isteklerde çift harcamayı engelleyen rezervasyon |
| `users/{uid}/coffee_reservations/{key}` | Analiz başlarken | Atomik rezervasyon ve süre sonu temizliği |
| `users/{uid}/wallet.credits` | AI validation **başarılı** | Düşürülmüş bakiye |
| `users/{uid}/credit_ledger/{id}` | AI validation **başarılı** | `type: debit`, `reason: coffee_reading`, `amount: -20` |
| `users/{uid}/idempotency/coffee_{key}` | Her callable (başarı/hata) | Response cache (çift jeton önleme) |

**AI validation başarısızsa:**

- `coffee_readings` **oluşturulmaz**
- `credit_ledger` debit **yazılmaz**
- `wallet.credits` **değişmez**
- ayrılan jeton rezervasyonu serbest bırakılır
- yüklenen fotoğraflar hemen silinir
- Sadece `idempotency` cache’lenir

**Başarılı AI validation sonrası:**

- Fotoğraflar en fazla **7 gün** tutulur
- `cleanupCoffeeArtifacts` zamanlanmış işi süre sonunda fotoğrafları siler
- Kullanıcı sonuç ekranından `Fotoğraflarımı Şimdi Sil` aksiyonuyla erken silebilir

### 8.3 Secret Manager

| Secret | Kullanım |
|--------|----------|
| `GEMINI_API_KEY` | Gemini Vision API (sadece backend) |

### 8.4 Geçici (fonksiyon belleği)

- Storage’dan indirilen JPEG buffer’ları
- Base64 encode edilmiş görseller
- Fonksiyon bitince bellek temizlenir; kalıcı depolama yok

---

## 9. Jeton (Credit) Kuralları

| Durum | Jeton |
|-------|-------|
| Lokal validation fail | Düşülmez (backend’e gitmez) |
| Backend AI validation fail | **0** (`chargedCredits: 0`) |
| Backend AI validation success | **20 jeton** (varsayılan) |
| Parser / AI teknik hata | Düşülmez |
| Aynı idempotency key tekrar | Cache’den döner, çift düşüş yok |

Env değişkeni: `COFFEE_READING_COST` (varsayılan: `20`)

**Flutter asla jeton düşmez** — tek kaynak backend Firestore transaction.

---

## 10. Oluşturulan / Güncellenen Dosyalar

### Flutter — Modeller
- `lib/src/features/coffee_reading/models/coffee_validation_failure_reason.dart` *(yeni)*
- `lib/src/features/coffee_reading/models/coffee_ai_validation_response.dart` *(yeni)*
- `lib/src/features/coffee_reading/models/coffee_ai_reading_response.dart` *(yeni)*
- `lib/src/features/coffee_reading/models/coffee_analyze_response.dart` *(yeni)*
- `lib/src/features/coffee_reading/models/coffee_validation_result.dart` *(genişletildi)*
- `lib/src/features/coffee_reading/models/coffee_reading_result.dart` *(genişletildi)*
- `lib/src/features/coffee_reading/models/coffee_image_pipeline_result.dart` *(fingerprint, fromGallery, sourceEvidence)*
- `lib/src/features/coffee_reading/models/coffee_image_source_evidence.dart` *(crop öncesi kaynak özeti)*

### Flutter — Servisler
- `coffee_image_quality_service.dart` *(yeni)*
- `coffee_residue_detection_service.dart` *(yeni)*
- `coffee_image_similarity_service.dart` *(yeni)*
- `coffee_screenshot_risk_service.dart` *(yeni)*
- `coffee_screen_spoofing_risk_service.dart` *(yeni)*
- `coffee_validation_service.dart` *(yeniden yazıldı — orchestrator)*
- `coffee_image_pipeline_service.dart` *(güncellendi)*
- `coffee_backend_service.dart` *(yeni — Storage upload)*
- `backend_coffee_reading_service.dart` *(yeni — gerçek backend)*
- `mock_coffee_reading_service.dart` *(güncellendi)*
- `coffee_reading_service.dart` *(interface güncellendi)*

### Flutter — UI
- `coffee_capture_flow_screen.dart` *(backend akışı, privacy, hata dialogları)*
- `coffee_loading_screen.dart` *(dinamik mesaj key)*
- `coffee_result_screen.dart` *(reading bölümleri + erken fotoğraf silme aksiyonu)*
- `coffee_validation_error_dialog.dart` *(yeni)*

### Flutter — Core
- `lib/src/core/tarot_functions_client.dart` → `analyzeCoffeeReading()`
- `lib/src/core/di/service_locator.dart` → tüm coffee servisleri + `TarotFunctionsClient`
- `lib/src/core/localization_service.dart` → validation / privacy / reading key’leri
- `pubspec.yaml` → `image: ^4.8.0` (görsel analiz için)

### Backend
- `functions/src/lib/coffee-reading.ts` *(yeni)*
- `functions/src/index.ts` → `analyzeCoffeeReading`, `deleteCoffeeReadingPhotos`, `cleanupCoffeeArtifacts`
- `storage.rules` → `coffee/{uid}/...` + **5 MB limit**

---

## 11. Deploy Edilen Kaynaklar

Aşağıdakiler `tarot-ai-dev-8f9a0` projesine deploy edildi:

| Kaynak | Durum |
|--------|-------|
| Cloud Function `analyzeCoffeeReading` | Deploy edildi |
| Cloud Function `deleteCoffeeReadingPhotos` | Deploy edildi |
| Scheduled Function `cleanupCoffeeArtifacts` | Deploy edildi |
| Storage / Firestore rules | Deploy edildi |

Deploy komutu:

```bash
cd functions && npm run build
cd .. && firebase deploy --only functions:analyzeCoffeeReading,functions:deleteCoffeeReadingPhotos,functions:cleanupCoffeeArtifacts,storage,firestore:rules
```

---

## 12. Test / Geliştirme Modları

### Mock backend (Gemini olmadan UI test)

```bash
flutter run --dart-define=USE_MOCK_COFFEE_READING=true
```

### Gerçek backend (varsayılan)

```bash
flutter run
```

Mock modda jeton düşülmez; 3 saniye delay ile sabit Türkçe reading döner.

---

## 13. Kabul Kriterleri Checklist

| Kriter | Durum |
|--------|-------|
| 3 fotoğraf zorunlu (iç, tabak, dış) | ✅ |
| Aynı fotoğraf 3 adımda kullanılamaz | ✅ (average hash ≥85%) |
| Boş / temiz fincan reddedilir | ✅ |
| Galeri daha sıkı doğrulanır | ✅ (0.78 vs 0.70) |
| Screenshot / stock risk reddi | ✅ |
| Screen spoofing reddi | ✅ |
| Bulanık / karanlık / parlak reddi | ✅ |
| Lokal fail → backend’e gitmez | ✅ |
| AI fail → reading null, jeton düşmez | ✅ |
| AI success → reading + jeton düşer | ✅ |
| API key Flutter’da yok | ✅ |
| Privacy metinleri gösterilir | ✅ |
| Storage JPEG max 5 MB | ✅ |
| Compress hedef ~500 KB | ✅ (quality 80, min 1024) |
| Kare crop zorunlu | ✅ |
| AppTexts localization | ✅ (TR + EN + DE JSON, TR + EN fallback) |

---

## 14. Bilinen Sınırlamalar / Sonraki Adımlar

1. **Lokal heuristikler %100 sahtecilik engellemez** — asıl gate backend AI validation’dır.
2. **`coffee_photo_preview_screen.dart`** eski tek-foto akışı; aktif flow `CoffeeCaptureFlowScreen`.
3. **App Check staged rollout:** İlk deploy ölçüm modundadır. TestFlight doğrulamasından sonra coffee callable için `enforceAppCheck: true` açılmalıdır.
4. **Storage App Check enforcement:** Ürün genelindeki mevcut upload akışları TestFlight’ta doğrulandıktan sonra Firebase Console’dan etkinleştirilmelidir.
5. **Node.js 20 runtime** Firebase tarafından deprecated uyarısı var; ileride Node 22’ye upgrade önerilir.

---

## 15. Mimari Diyagram

```
┌─────────────────────────────────────────────────────────────┐
│                        FLUTTER (Cihaz)                       │
│  Pick (1600px) → Crop (1:1) → Compress (JPEG q80, ~500KB)   │
│  → ML Kit + Heuristics (score ≥0.70/0.78)                   │
│  → Kullanıcı CTA onayı (20 jeton)                            │
│  → Firebase Storage upload (max 5MB/JPEG per storage.rules)  │
└────────────────────────────┬────────────────────────────────┘
                             │ HTTPS Callable
                             ▼
┌─────────────────────────────────────────────────────────────┐
│              Cloud Function: analyzeCoffeeReading            │
│  1. Auth + atomik credit reservation + rate limit           │
│  2. Exact Storage path / JPEG / size validation             │
│  3. Download 3 images from Storage                          │
│  4. Gemini Flash-Lite — structured JSON (validate → read)   │
│  5. If valid: debit credits + retain images max 7 days      │
│  6. If invalid/error: release reservation + delete images   │
└────────────────────────────┬────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
   Firebase Storage      Firestore            Gemini API
   coffee/{uid}/...     wallet, ledger,     (GEMINI_API_KEY
                         coffee_readings      in Secret Manager)
```

---

*Bu doküman Kahve Falı spesifikasyon implementasyonunun teknik referansıdır.*
