# Camera Logging Guide

Bu kılavuz, iOS kamera önizlemesi açılmadığında Xcode debug build almadan log toplamak için kullanılır.

## Ne Loglanır?

`CameraDiagnostics` şu olayları `camera` adıyla kaydeder:

- `permission_status` / `permission_request_done`: Kamera izninin mevcut ve istek sonrası durumu.
- `available_cameras_start` / `available_cameras_done`: `availableCameras()` çağrısı ve dönen kamera sayısı/lens listesi.
- `camera_selected`: Uygulamanın seçtiği kamera. El falında beklenen değer `lensDirection: back`.
- `initialize_start` / `initialize_done`: `CameraController.initialize()` başlangıcı ve başarılı bitişi.
- `initialize_error` / `initialize_camera_exception`: Kamera initialize hatası, exception tipi, mesaj ve stack trace.
- `take_picture_start` / `take_picture_done`: Fotoğraf çekme başlangıcı ve sonucu.
- `image_stream_start` / `image_stream_started` / `image_stream_stop`: Apple Vision frame stream yaşam döngüsü.
- `palmvision_result`: Native Vision analiz sonucu (`handDetected`, `validPalm`, `scanState`, debug alanları).

Loglar üç yere yazılır:

- `debugPrint` ve `developer.log(name: 'camera')`
- Uygulama içi son 200 satırlık ring-buffer
- Oturum açıksa Firestore: `diagnostics/{uid}/camera/{autoId}`

Firestore yazımı best-effort çalışır; hata verirse kamera akışını bozmaz.

## Release/Profile Build'de Tanı Logunu Açma

Dart release logları her zaman görünmeyebilir. Bu yüzden iki yol vardır:

```bash
flutter run --profile -d <device-id> --dart-define=CAMERA_DIAGNOSTICS_ENABLED=true
```

veya uygulama içinde `SharedPreferences` değeri açılmışsa:

```text
cameraDiagnosticsEnabled = true
```

Native taraf ayrıca `os_log` ile `subsystem=com.tarotai`, `category=camera` yazar.

## Xcode GUI Olmadan Dart Logları

Cihaz id'sini bul:

```bash
flutter devices
```

Profil build çalıştır:

```bash
flutter run --profile -d <device-id> --dart-define=CAMERA_DIAGNOSTICS_ENABLED=true
```

Çalışan uygulamaya bağlan:

```bash
flutter attach -d <device-id>
```

Dart loglarını izle:

```bash
flutter logs -d <device-id>
```

Aranacak anahtarlar:

```text
[...][palm_scanner] initialize_start
[...][palm_scanner] initialize_done
[...][onboarding_palm] initialize_error
[...][palm_vision] palmvision_result
```

## TestFlight / Release Native Logları

`libimobiledevice` kur:

```bash
brew install libimobiledevice
```

Cihaz bağlıyken native logları filtrele:

```bash
idevicesyslog | grep -iE "Runner|camera|AVCapture|palmvision|tarot_ai|com.tarotai"
```

Beklenen native işaretçiler:

```text
AppDelegate didFinishLaunching
Implicit Flutter engine initialized
Registering device_info channel
PalmVisionPlugin register
PalmVisionPlugin method=analyzePalmFrame
PalmVisionPlugin analyze done hand=... validPalm=...
```

## Console.app ile Log Okuma

1. iPhone'u Mac'e bağla.
2. macOS `Console.app` uygulamasını aç.
3. Sol taraftan cihazı seç.
4. Arama/filtre alanına şunlardan birini yaz:
   - `process:Runner`
   - `subsystem:com.tarotai`
   - `camera`
   - `AVCapture`
5. El falı ekranını aç ve kamera izin akışını tekrar dene.

## Firestore Üzerinden Uzaktan Okuma

Firebase Console:

```text
diagnostics/{uid}/camera
```

CLI ile okumak istersen küçük bir `firebase-admin` script'i kullanman gerekir; Firestore
konsolu bu teşhis için en güvenilir yoldur. Kayıtları `createdAt` alanına göre yeniden eskiye
sıralayıp son oturumdaki `sessionId` değerini takip et.

## Hızlı Teşhis

- `available_cameras_done count=0`: iOS kamera listesi boş dönüyor.
- `camera_selected lensDirection=front`: Arka kamera seçilememiş, fallback olarak ilk kamera alınmış.
- `initialize_error`: Asıl sebep burada; `CameraAccessDenied`, `CameraAccessRestricted`, `AVCapture` hataları aranmalı.
- `initialize_done` var ama preview görünmüyorsa: UI/preview layer veya lifecycle sorunu.
- `image_stream_start_error`: Preview açılmış ama Apple Vision frame stream başlayamamış.
- `PalmVisionPlugin method=analyzePalmFrame` hiç yoksa: MethodChannel/plugin kaydı veya stream akışı çalışmıyor.
