# Aylık Premium abonelik — App Store Connect kurulumu

Uygulama ve sunucu şu **Product ID** ile hazır:

| Alan | Değer |
|------|--------|
| Product ID | `tarotai.premium.monthly` |
| Süre | 1 ay (otomatik yenileme) |
| Bundle ID | `com.tarotai` |
| Sandbox / StoreKit | `ios/Runner/TarotAi.storekit` içinde tanımlı |

Satın alma sonrası backend: premium aktif + **200 bonus jeton** (`functions/src/lib/purchase.ts`).

---

## 0. Ön koşul (jeton paketleriyle aynı)

1. [App Store Connect](https://appstoreconnect.apple.com/) → **Business** → **Agreements, Tax, and Banking**
2. **Paid Applications** sözleşmesi **Active** olmalı.
3. Uygulama **TarotAi**, Bundle ID **`com.tarotai`**.

Abonelik oluşturamazsanız önce sözleşmeyi tamamlayın.

---

## 1. Abonelik grubu oluştur

1. **Apps** → **TarotAi** seçin.
2. Sol menü: **Monetization** → **Subscriptions** (bazı arayüzlerde **Features** → **Subscriptions**).
3. **Create Subscription Group** (veya **+**).
4. **Subscription Group Reference Name:** `TarotAi Premium` (sadece sizin görünür).
5. **App Store Localization** (grup için — kullanıcı “Aboneliklerim”de görür):
   - **Turkish:** Display Name `TarotAi Premium`
   - **English (U.S.):** Display Name `TarotAi Premium`
6. Kaydedin.

> Tek premium planınız varsa bir grup yeterli. İleride yıllık plan eklerseniz aynı gruba koyun (kullanıcı aynı anda yalnızca birini seçer).

---

## 2. Aylık aboneliği oluştur

Grubun içinde **Create Subscription**:

| Alan | Değer |
|------|--------|
| **Reference Name** | `Premium Monthly` |
| **Product ID** | `tarotai.premium.monthly` (**aynen**, sonra değişmez) |
| **Subscription Duration** | **1 Month** |

### Fiyat

1. **Subscription Prices** → **+** → ülke / fiyat katmanı (ör. Türkiye için uygun tier).
2. **Save** ile fiyatı kilitleyin.

### Yerelleştirme (Subscription Localization)

Her dil için **Display Name** ve **Description** doldurun:

**Turkish**

- **Display Name:** `Aylık Premium`
- **Description:** `Reklamsız kullanım, detaylı AI yorumları ve her abonelik döneminde 200 bonus jeton. Abonelik her ay otomatik yenilenir; App Store hesap ayarlarından iptal edebilirsiniz.`

**English (U.S.)**

- **Display Name:** `Monthly Premium`
- **Description:** `Ad-free experience, deeper AI readings, and 200 bonus tokens each billing period. Renews monthly; cancel anytime in App Store account settings.`

### İnceleme ekran görüntüsü (çoğu “Missing Metadata” bunun için)

1. Abonelik sayfasında **App Review Information** bölümüne inin.
2. **Screenshot for Review:** Kozmik Cüzdan’daki **Aylık Premium** kartının göründüğü iPhone ekran görüntüsü.
3. Çözünürlük: Apple’ın istediği cihaz boyutu (ör. 6.7" → 1290×2796 px).

Jeton paketlerindeki kuralların aynısı geçerli; **Offer Codes zorunlu değil**.

### Gizlilik / yasal (aboneliklerde sık istenen)

1. **App Store** sekmesinde uygulama → **App Privacy** ve **Privacy Policy URL** dolu olsun.  
   Uygulama varsayılanı: `https://tarotai.app/privacy` (Remote Config `shop_config_v1` → `legal.privacyUrl`).
2. Abonelik sayfasında **Subscription Terms** / EULA: Apple standart metnini kullanabilir veya kendi şartlarınızın linkini verebilirsiniz.
3. Uygulama içinde zaten `premiumCancelInfo` ve `premiumAutoRenewInfo` metinleri var; mağaza açıklamasında da yenileme/iptali belirtin.

Durum **Ready to Submit** (veya onay sonrası **Approved**) olana kadar eksik alanları tamamlayın.

---

## 3. Uygulama sürümüne bağlama (ilk kez IAP/abonelik ekliyorsanız)

1. **TestFlight** veya **App Store** için bir **build** yükleyin (Xcode → Archive).
2. **App Store** sekmesi → sürüm → **In-App Purchases and Subscriptions** (veya benzeri bölüm).
3. `tarotai.premium.monthly` (ve jeton ürünlerini) bu sürüme **+** ile ekleyin.
4. İncelemeye gönderirken abonelikler paketle birlikte gider.

Sandbox test için bazen metadata + screenshot yeterli olur; yine de bir build yüklemek ilk yayında sorun çıkarmaz.

---

## 4. Sandbox ile test

1. **Users and Access** → **Sandbox** → **Sandbox Apple Accounts** → test hesabı oluşturun.
2. iPhone: **Ayarlar → App Store → Sandbox Account** ile giriş.
3. Uygulamayı **gerçek cihaza** `com.tarotai` imzalı build ile yükleyin.
4. **Kozmik Cüzdan** → **Aylık Premium** → satın al (sandbox’ta ücret alınmaz).
5. Başarılı olunca Firestore’da `entitlements.premium.active: true` ve jeton +200 kontrol edin.
6. **Satın alımları geri yükle** ile restore deneyin (abonelik için önemli).

Yeni abonelik mağazaya **15 dk – birkaç saat** gecikmeyle yansıyabilir. Fiyat gelmiyorsa uygulamayı kapatıp açın veya mağaza ürünlerini yeniden yükleyin.

### Simulator (StoreKit dosyası)

Xcode → **Edit Scheme** → **Run** → **Options** → **StoreKit Configuration:** `TarotAi.storekit`  
Simulator’da premium fiyatı dosyadan gelir; Connect’teki kayıt yerine geçmez.

---

## 5. Android (Google Play) — aynı Product ID

1. Play Console → **Monetize** → **Subscriptions** (In-app products değil).
2. Yeni abonelik → Product ID: `tarotai.premium.monthly`
3. Base plan: aylık, fiyat, **Active**
4. Test için internal testing + license testers (bkz. `SHOP_IAP_KURULUM.md`).

---

## 6. Projede kontrol listesi (kod tarafı — değiştirmeniz gerekmez)

- [x] `ShopProductCatalog.premiumMonthly` = `tarotai.premium.monthly`
- [x] `shop_config_v1` fallback → `premium` dizisinde aynı ID
- [x] `purchase_service.dart` → abonelik için `buyNonConsumable`
- [x] `functions` doğrulama → `monthly_premium` + 200 jeton

**Remote Config** kullanıyorsanız Firebase’de `shop_config_v1` içinde:

```json
"premium": [
  {
    "productId": "tarotai.premium.monthly",
    "titleKey": "premiumMonthlyTitle",
    "subtitleKey": "premiumMonthlySubtitle",
    "featureKeys": [
      "premiumFeatureNoAds",
      "premiumFeatureBonusCredits",
      "premiumFeatureDeepReadings",
      "premiumFeaturePersonalizedExperience",
      "premiumFeaturePremiumAiDepth"
    ],
    "badgeKey": "premiumBadgePopular",
    "iconKey": "premium",
    "sortOrder": 10,
    "isActive": true,
    "isHighlighted": true
  }
]
```

`productId` farklı yazılırsa uygulama mağazada ürünü bulamaz.

---

## 7. Sık sorunlar

| Belirti | Olası neden |
|--------|-------------|
| Premium fiyatı “kullanılamıyor” | Connect’te abonelik eksik metadata, yanlış Product ID, veya henüz yayılmadı |
| Jeton geldi ama premium rozet yok | `verifyPurchase` / sandbox receipt; Functions deploy |
| “Product ID already used” | Aynı ID başka uygulamada veya eski kayıtta — yeni ID kullanırsanız kod + backend map güncellenmeli |
| Simulator’da yok | StoreKit Configuration seçilmemiş |
| Restore boş | Sandbox’ta aktif abonelik yok veya farklı sandbox hesabı |

---

## 8. Connect’te doldururken hızlı özet

1. Grup: `TarotAi Premium`
2. Abonelik ID: `tarotai.premium.monthly`, süre **1 Month**
3. Fiyat + TR/EN yerelleştirme (yukarıdaki metinler)
4. Review screenshot (Premium kartı)
5. Ready to Submit → sandbox test → sürüme aboneliği ekle

Sorun yaşarsanız abonelik sayfasının **Status** satırını ve eksik uyarıları (sarı kutu) ekran görüntüsüyle paylaşın.
