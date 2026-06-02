import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

Future<void> activateAppCheck({required bool isDebug}) async {
  // Debug/emulator: App Check "Too many attempts" Storage isteklerini bozabiliyor.
  if (isDebug) {
    debugPrint('App Check disabled in debug builds.');
    return;
  }
  try {
    await FirebaseAppCheck.instance.activate(
      appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
      androidProvider: AndroidProvider.playIntegrity,
    );
  } catch (error, stackTrace) {
    debugPrint('App Check activation skipped: $error');
    if (kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
