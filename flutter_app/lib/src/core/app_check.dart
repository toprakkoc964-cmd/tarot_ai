import 'package:firebase_app_check/firebase_app_check.dart';

Future<void> activateAppCheck({required bool isDebug}) async {
  await FirebaseAppCheck.instance.activate(
    appleProvider: isDebug
        ? AppleProvider.debug
        : AppleProvider.appAttestWithDeviceCheckFallback,
    androidProvider: AndroidProvider.debug,
  );
}
