# Jeton / Premium satın alma (IAP) kurulumu

Uygulama şu ürün kimliklerini sorgular:

| Ürün | Product ID | Tür |
|------|------------|-----|
| 50 Jeton | `tarotai.jeton.50` | Tüketilebilir |
| 250 Jeton | `tarotai.credits.250` | Tüketilebilir |
| 1000 Jeton | `tarotai.credits.1000` | Tüketilebilir |
| Premium Aylık | `tarotai.premium.monthly` | Abonelik |

Kimlikler birebir aynı olmalıdır (büyük/küçük harf dahil).

## Android (Google Play)

1. **Paket adı:** `com.example.tarot_ai` (`android/app/build.gradle.kts` → `applicationId`)
2. [Google Play Console](https://play.google.com/console) → Uygulama → **Monetize** → **Products** → **In-app products**
3. Her product ID için ürün oluştur ve **Active** yap
4. Uygulamayı en az **Internal testing** kanalına yükle (imzalı APK/AAB)
5. Test hesabını **License testers** listesine ekle
6. Test için **Play Store yüklü** emülatör veya fiziksel cihaz kullan (APK sideload ile IAP çalışmaz)

## iOS — Apple Developer / App Store Connect (adım adım)

Ürünler **App Store Connect**’te tanımlanır (Apple Developer hesabı üzerinden). Kodda kullanılan **Bundle ID:** `com.tarotai`.

### 0. Ön koşullar

1. [Apple Developer Program](https://developer.apple.com/programs/) üyeliği (yıllık ücret).
2. [App Store Connect](https://appstoreconnect.apple.com/) → giriş yap.
3. **Agreements, Tax, and Banking** bölümünde **Paid Applications** sözleşmesi **Active** olmalı. İmza, vergi ve banka bilgisi eksikse IAP oluşturamazsın.
4. App Store Connect’te **TarotAi** uygulaması kayıtlı olmalı; Bundle ID **`com.tarotai`** ile eşleşmeli (Xcode’daki `PRODUCT_BUNDLE_IDENTIFIER` ile aynı).

Yeni uygulama yoksa: **Apps** → **+** → **New App** → platform iOS, isim, dil, Bundle ID listesinden `com.tarotai` seç (yoksa önce [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) → **Identifiers** → **+** → **App IDs** → `com.tarotai` oluştur).

### 1. Jeton paketleri (Consumable — tüketilebilir)

Her jeton paketi için ayrı ürün:

| Sıra | Product ID (Reference Name örnek) | Tür |
|------|-----------------------------------|-----|
| 1 | `tarotai.jeton.50` | Consumable |
| 2 | `tarotai.credits.250` | Consumable |
| 3 | `tarotai.credits.1000` | Consumable |

**App Store Connect’te:**

1. Uygulamanı seç → sol menü **Monetization** (veya **Features**) → **In-App Purchases**.
2. **+** (Create) → **Consumable**.
3. **Reference Name:** iç kullanım (ör. `50 Credits`) — kullanıcı görmez.
4. **Product ID:** tablodaki kimlik **aynen** (ör. `tarotai.jeton.50`). Oluşturduktan sonra ID değiştirilemez. (`tarotai.credits.50` ekibinizde başka kayıtta kullanılıyorsa yeni ID kullanın ve kodu güncelleyin.)
5. **Price Schedule:** fiyat katmanı seç (ör. Tier uygun TRY fiyatı).
6. **App Store Localization:** görünen ad ve açıklama (ör. Türkçe: “50 Jeton”, “Tek seferlik 50 jeton paketi”).
7. İsteğe bağlı ekran görüntüsü / review notu.
8. **Save** → durum **Ready to Submit** olana kadar eksik alanları doldur.
9. Diğer iki jeton için 2–8’i tekrarla.

### 2. Premium aylık (Auto-Renewable Subscription)

Product ID: `tarotai.premium.monthly`

**Detaylı adım adım rehber (grup, fiyat, TR/EN metinler, ekran görüntüsü, sandbox):**  
→ [`docs/SHOP_PREMIUM_ABONELIK.md`](./SHOP_PREMIUM_ABONELIK.md)

Kısa özet:

1. **Monetization** → **Subscriptions** → **Create Subscription Group** (`TarotAi Premium`).
2. Grupta **Create Subscription** → Product ID **`tarotai.premium.monthly`**, süre **1 Month**.
3. Fiyat + **Turkish / English** Display Name & Description (rehberde kopyala-yapıştır metinler).
4. **Screenshot for Review** — Kozmik Cüzdan’daki Aylık Premium kartı (1290×2796 vb.).
5. Privacy Policy URL (uygulama: `https://tarotai.app/privacy`) ve yenileme/iptal metni.
6. Durum **Ready to Submit** → sandbox test → App Store sürümüne aboneliği ekle.

### 3. Sandbox ile gerçek cihazda test

App Store Connect ürünleri canlıya çıkmadan test edilir:

1. **Users and Access** → **Sandbox** → **Sandbox Apple Accounts** → test Apple ID oluştur (gerçek Apple ID’nden farklı e-posta).
2. iPhone’da **Ayarlar → App Store → Sandbox Hesabı** (veya eski iOS’ta test hesabıyla App Store girişi) — sandbox hesabıyla giriş.
3. Uygulamayı Xcode’dan **gerçek cihaza** yükle (`com.tarotai` imzalı build).
4. Kozmik Cüzdan’da satın al; sandbox’ta gerçek para çekilmez.

Not: Ürünler yeni oluşturulduysa mağazaya yansıması **birkaç dakika – birkaç saat** sürebilir. Hâlâ “kullanılamıyor” görürsen uygulamayı kapat-aç veya **Ürünleri yeniden yükle**.

### 4. Simulator (StoreKit — App Store Connect’siz hızlı test)

Gerçek ürün kaydı beklemeden UI testi:

1. Mac’te `ios/Runner.xcodeproj` aç.
2. **Product → Scheme → Edit Scheme…** → **Run** → **Options**.
3. **StoreKit Configuration:** `TarotAi.storekit` seç (projede `ios/Runner/TarotAi.storekit`).
4. Simulator’da çalıştır; fiyatlar yerel StoreKit dosyasından gelir.

Bu, App Store Connect’teki ürünlerin yerine geçmez; sadece geliştirme içindir. Canlı / TestFlight testi için Connect’te ürünler şart.

### 5. TestFlight / App Store’a gönderirken

- İlk kez IAP ekliyorsan, uygulama sürümü (**App Store** sekmesi) ile birlikte **In-App Purchases** ve **Subscriptions** da incelemeye gider; sürümde “In-App Purchases” bölümünden bu ürünleri sürüme ekle.
- Binary (build) yüklendikten sonra ürünler sürümle ilişkilendirilmiş olmalı.

### 6. “Missing Metadata” (Offer Codes değil)

Durum sarı **Missing Metadata** ise sebep neredeyse her zaman **Offer Codes değildir**. Offer Codes promosyon içindir; boş bırakılabilir.

Sırayla kontrol et (250 Jeton / Consumable sayfasında aşağı kaydır):

1. **App Store Localization**
   - En az bir dilde **Display Name** ve **Description** dolu olsun (boş veya “Prepare for Submission” uyarısı kalmasın).
   - Uygulama Türkçe ise **Turkish** yerelleştirme ekle: görünen ad `250 Jeton`, açıklama örn. `Tek seferlik 250 jeton paketi`.
   - English (U.S.) varsa Display Name ve Description aynı metinle doldurulmuş olsun.

2. **Screenshot for Review** (en sık eksik olan)
   - Aynı IAP sayfasında **App Review Information** / **Screenshot for Review** bölümü.
   - Uygulamada jeton satın alma ekranının (Kozmik Cüzdan) **gerçek ekran görüntüsünü** yükle (iPhone çözünürlüğü).
   - Bu olmadan çoğu Consumable **Missing Metadata**’da kalır.

3. **Pricing**
   - **Current Price** seçili ve kayıtlı olsun (sende 175 ülke görünüyorsa genelde tamam).

4. **Product ID**
   - `tarotai.credits.250` olmalı (Reference Name `250 Jeton` olabilir; ID farklıdır).

5. **Offer Codes**
   - **Gerekmez.** “Create Offer”e basma; Missing Metadata’yı çözmez.

6. **İlk IAP + uygulama sürümü**
   - Üstteki mavi kutu: ilk kez IAP ekliyorsan, bir **build** (TestFlight/App Store) yükleyip sürümle IAP’leri ilişkilendirmen gerekebilir. Sandbox test için bazen sadece metadata + screenshot yeterli olur; “Ready to Submit” için sürüm şart olabilir.

Metadata tamamlanınca durum **Ready to Submit** veya **Approved**’a döner (birkaç dakika sürebilir).

### 7. Kontrol listesi

- [ ] Paid Applications sözleşmesi Active
- [ ] Bundle ID `com.tarotai`
- [ ] 3 × Consumable ID’ler birebir doğru
- [ ] 1 × Subscription `tarotai.premium.monthly` grup içinde
- [ ] Tüm ürünler Ready to Submit (veya Approved)
- [ ] Sandbox test hesabı ile gerçek cihazda denendi

## Firebase Remote Config

`shop_config_v1` anahtarındaki `productId` alanları yukarıdaki kimliklerle aynı olmalı. Farklı ID yazılırsa mağaza ürünü bulunamaz.

## Sık hatalar

- **“Ürün şu anda kullanılamıyor”:** Mağazada ürün yok, paket adı uyuşmuyor veya test build Play’e yüklenmemiş
- **Emülatör (Google APIs olmayan):** `isAvailable()` false döner
- **iOS Simulator StoreKit seçilmemiş:** Ürünler `notFound` döner
