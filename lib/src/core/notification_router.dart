import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/coffee_reading/screens/coffee_capture_flow_screen.dart';
import '../features/home/home_page.dart';
import '../features/home/messages_page.dart';
import '../features/palmistry/screens/palm_scanner_screen.dart';
import 'app_navigator.dart';

class NotificationRouter {
  const NotificationRouter._();

  static Future<void> handleNotificationTap(Map<dynamic, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final normalized = data.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
    final route = normalized['route']?.trim();
    final type = normalized['type']?.trim();

    if (type == 'reading_audio_ready') {
      await _push(
        MessagesPage(uid: user.uid, bottomInset: 24, showBackButton: true),
      );
      return;
    }

    switch (route) {
      case '/coffee':
        await _push(CoffeeCaptureFlowScreen(uid: user.uid));
        return;
      case '/palm':
        await _push(const PalmScannerScreen());
        return;
      case '/shop':
        if (!HomePage.openTab(2)) {
          await _waitAndOpenHomeTab(2);
        }
        return;
      case '/daily':
        if (!HomePage.openTab(0)) {
          await _waitAndOpenHomeTab(0);
        }
        return;
      default:
        if (type == 'wallet_low' || type == 'wallet_offer') {
          HomePage.openTab(2);
        } else if (type == 'daily_card' || type == 'birth_chart_fallback') {
          HomePage.openTab(0);
        }
    }
  }

  static Future<void> _push(Widget page) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  static Future<void> _waitAndOpenHomeTab(int index) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    HomePage.openTab(index);
  }
}
