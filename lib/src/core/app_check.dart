import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

Future<void> activateAppCheck({required bool isDebug}) async {
  if (isDebug) {
    debugPrint('App Check skipped for local debug builds.');
    return;
  }

  await FirebaseAppCheck.instance.activate(
    appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
    androidProvider: AndroidProvider.debug,
  );
}
