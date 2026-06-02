import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

Future<void> activateAppCheck({required bool isDebug}) async {
  await FirebaseAppCheck.instance.activate(
    appleProvider: isDebug
        ? AppleProvider.debug
        : AppleProvider.appAttestWithDeviceCheckFallback,
    androidProvider: AndroidProvider.debug,
  );
  if (isDebug) {
    debugPrint('App Check debug provider is active.');
  }
}
