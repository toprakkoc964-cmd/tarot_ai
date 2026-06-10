import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';
import '../features/auth/user_profile_contract.dart';

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    required this.source,
  });

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final String source;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'receivedAt': receivedAt.toIso8601String(),
      'source': source,
    };
  }

  factory AppNotificationItem.fromMap(Map<String, dynamic> map) {
    return AppNotificationItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      receivedAt:
          DateTime.tryParse(map['receivedAt'] as String? ?? '') ??
          DateTime.now(),
      source: map['source'] as String? ?? 'unknown',
    );
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _storedNotificationsKey = 'stored_notifications_v1';
  static const _campaignTopicKey = 'campaign_topic_v1';
  static const _maxStoredNotifications = 25;
  static const _deviceInfoChannel = MethodChannel('tarot_ai/device_info');

  final ValueNotifier<List<AppNotificationItem>> inbox =
      ValueNotifier<List<AppNotificationItem>>(const []);
  final ValueNotifier<String?> apnsToken = ValueNotifier<String?>(null);
  final ValueNotifier<String?> fcmToken = ValueNotifier<String?>(null);
  final ValueNotifier<String> permissionStatus = ValueNotifier<String>(
    'unknown',
  );

  bool _initialized = false;
  bool _isIosSimulator = false;
  bool _messageListenersRegistered = false;
  bool _authListenersRegistered = false;
  bool _languageListenerRegistered = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _loadStoredNotifications();

    _isIosSimulator = await _detectIosSimulator();

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.getNotificationSettings();
    permissionStatus.value = settings.authorizationStatus.name;
    debugPrint(
      'Notification permission status: ${settings.authorizationStatus}',
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _registerMessageListeners();
    _registerAuthListeners();
    _registerLanguageListener();

    if (!kIsWeb && Platform.isIOS) {
      if (_isIosSimulator) {
        debugPrint(
          'Running on iOS Simulator. Skipping APNs and FCM token setup.',
        );
        await syncNotificationContextForCurrentUser();
        return;
      }

      if (!_isPermissionGranted(settings.authorizationStatus)) {
        await syncNotificationContextForCurrentUser();
        return;
      }

      final apnsToken = await _waitForApnsToken(messaging);
      if (apnsToken == null) {
        debugPrint(
          'APNs token was not available within 10 seconds. '
          'Skipping FCM token fetch on iOS.',
        );
        await syncNotificationContextForCurrentUser();
        return;
      }

      this.apnsToken.value = apnsToken;
      debugPrint('APNs Token: $apnsToken');
    }

    await _syncFcmToken();
    await syncNotificationContextForCurrentUser();
  }

  Future<String> requestNotificationPermissions() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    permissionStatus.value = settings.authorizationStatus.name;

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (!_isPermissionGranted(settings.authorizationStatus)) {
      return settings.authorizationStatus.name;
    }

    if (!kIsWeb && Platform.isIOS && !_isIosSimulator) {
      final token = await _waitForApnsToken(messaging);
      if (token != null && token.isNotEmpty) {
        apnsToken.value = token;
        debugPrint('APNs Token: $token');
      }
    }

    await _syncFcmToken();
    await syncNotificationContextForCurrentUser();
    return settings.authorizationStatus.name;
  }

  Future<void> _handleAuthChange(User? user) async {
    if (user != null) {
      await _syncFcmToken();
      await syncNotificationContextForCurrentUser();
    }
  }

  Future<void> _handleTokenRefresh(String token) async {
    if (_shouldSkipFcmTokenWork()) return;

    fcmToken.value = token;
    debugPrint('FCM Token refreshed: $token');
    await _persistTokenForCurrentUser(token);
    await _syncCampaignTopicForCurrentLanguage();
    await syncNotificationContextForCurrentUser();
  }

  Future<void> _syncFcmToken() async {
    if (_shouldSkipFcmTokenWork()) return;

    final token = await FirebaseMessaging.instance.getToken();
    fcmToken.value = token;
    debugPrint('FCM Token: $token');
    if (token == null || token.isEmpty) return;
    await _persistTokenForCurrentUser(token);
    await _syncCampaignTopicForCurrentLanguage();
  }

  Future<void> _persistTokenForCurrentUser(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection(UserProfileContract.usersCollection)
        .doc(user.uid)
        .set({
          UserProfileContract.fcmTokens: FieldValue.arrayUnion([token]),
          UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
          UserProfileContract.fcmTokenUpdatedAt: FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<String?> _resolveDeviceTimezone() async {
    try {
      final dynamic timezone = await FlutterTimezone.getLocalTimezone();
      if (timezone is String) return timezone;

      final dynamic identifier = timezone.identifier;
      return identifier is String ? identifier : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _defaultNotificationPrefs() => <String, dynamic>{
    'enabled': true,
    'dailyBirthChart': <String, dynamic>{'enabled': true, 'hourLocal': 9},
    'dailyCard': <String, dynamic>{'enabled': true, 'hourLocal': 9},
    'coffeePalmFollowup': <String, dynamic>{'enabled': true},
    'walletOffers': <String, dynamic>{'enabled': true},
  };

  Future<void> syncNotificationContextForCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docRef = FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(user.uid);

      final timezone = (await _resolveDeviceTimezone())?.trim();
      final update = <String, dynamic>{
        UserProfileContract.language: AppLocale.current,
        UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
      };

      if (timezone != null && timezone.isNotEmpty) {
        update[UserProfileContract.timezone] = timezone;
        update[UserProfileContract.timezoneUpdatedAt] =
            FieldValue.serverTimestamp();
      }

      final snapshot = await docRef.get();
      final data = snapshot.data();
      if (data == null ||
          !data.containsKey(UserProfileContract.notificationPrefs)) {
        update[UserProfileContract.notificationPrefs] =
            _defaultNotificationPrefs();
      }

      await docRef.set(update, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Notification context sync skipped: $error');
    }
  }

  void _registerMessageListeners() {
    if (_messageListenersRegistered) return;
    _messageListenersRegistered = true;

    FirebaseMessaging.onMessage.listen(
      (message) => recordRemoteMessage(message, source: 'foreground'),
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => recordRemoteMessage(message, source: 'opened_app'),
    );

    FirebaseMessaging.instance.getInitialMessage().then((initialMessage) async {
      if (initialMessage != null) {
        await recordRemoteMessage(initialMessage, source: 'launch');
      }
    });
  }

  void _registerAuthListeners() {
    if (_authListenersRegistered) return;
    _authListenersRegistered = true;

    FirebaseMessaging.instance.onTokenRefresh.listen(_handleTokenRefresh);
    FirebaseAuth.instance.authStateChanges().listen(_handleAuthChange);
  }

  void _registerLanguageListener() {
    if (_languageListenerRegistered) return;
    _languageListenerRegistered = true;

    AppLocale.notifier.addListener(() {
      unawaited(_syncCampaignTopicForCurrentLanguage());
      unawaited(syncNotificationContextForCurrentUser());
    });
  }

  bool _isPermissionGranted(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  bool _shouldSkipFcmTokenWork() {
    return !kIsWeb && Platform.isIOS && _isIosSimulator;
  }

  Future<bool> _detectIosSimulator() async {
    if (kIsWeb || !Platform.isIOS) return false;

    try {
      final result = await _deviceInfoChannel.invokeMethod<bool>(
        'isIosSimulator',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> reloadInbox() async {
    await _loadStoredNotifications();
  }

  Future<void> deleteNotification(String id) async {
    if (id.trim().isEmpty) return;
    inbox.value = inbox.value
        .where((item) => item.id != id)
        .toList(growable: false);
    await _persistNotifications();
  }

  Future<void> clearInbox() async {
    inbox.value = const [];
    await _persistNotifications();
  }

  Future<void> recordRemoteMessage(
    RemoteMessage message, {
    required String source,
    String? overrideTitle,
    String? overrideBody,
  }) async {
    final notification = message.notification;
    final title = notification?.title?.trim();
    final body = notification?.body?.trim();

    final fallbackTitle = message.data['title']?.toString().trim();
    final fallbackBody = message.data['body']?.toString().trim();

    await storeNotification(
      id: message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: (overrideTitle?.trim().isNotEmpty ?? false)
          ? overrideTitle!.trim()
          : (title?.isNotEmpty ?? false)
          ? title!
          : (fallbackTitle?.isNotEmpty ?? false)
          ? fallbackTitle!
          : 'New notification',
      body: (overrideBody?.trim().isNotEmpty ?? false)
          ? overrideBody!.trim()
          : (body?.isNotEmpty ?? false)
          ? body!
          : (fallbackBody?.isNotEmpty ?? false)
          ? fallbackBody!
          : 'Open the app to view the latest update.',
      source: source,
    );
  }

  Future<void> storeNotification({
    required String id,
    required String title,
    required String body,
    required String source,
    DateTime? receivedAt,
  }) async {
    final item = AppNotificationItem(
      id: id,
      title: title,
      body: body,
      receivedAt: receivedAt ?? DateTime.now(),
      source: source,
    );
    final current = inbox.value;
    final deduped = current.where((entry) => entry.id != item.id).toList();
    inbox.value = <AppNotificationItem>[
      item,
      ...deduped,
    ].take(_maxStoredNotifications).toList(growable: false);
    await _persistNotifications();

    debugPrint('Notification saved: ${item.title} (${item.source})');
  }

  Future<void> _loadStoredNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storedNotificationsKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      inbox.value = decoded
          .whereType<Map<String, dynamic>>()
          .map(AppNotificationItem.fromMap)
          .toList(growable: false);
    } catch (_) {
      inbox.value = const [];
    }
  }

  Future<void> _persistNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      inbox.value.map((item) => item.toMap()).toList(growable: false),
    );
    await prefs.setString(_storedNotificationsKey, encoded);
  }

  Future<void> _syncCampaignTopicForCurrentLanguage() async {
    final token = fcmToken.value ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final previousTopic = prefs.getString(_campaignTopicKey);
    final nextTopic = _campaignTopicForLanguage(AppLocale.current);

    if (previousTopic == nextTopic) return;

    if (previousTopic != null && previousTopic.isNotEmpty) {
      await FirebaseMessaging.instance.unsubscribeFromTopic(previousTopic);
      debugPrint('Unsubscribed from campaign topic: $previousTopic');
    }

    await FirebaseMessaging.instance.subscribeToTopic(nextTopic);
    await prefs.setString(_campaignTopicKey, nextTopic);
    debugPrint('Subscribed to campaign topic: $nextTopic');
  }

  String _campaignTopicForLanguage(String langCode) {
    final normalized = langCode.trim().toLowerCase();
    final safeCode = normalized.isEmpty ? 'en' : normalized;
    return 'campaigns_$safeCode';
  }

  Future<String?> _waitForApnsToken(FirebaseMessaging messaging) async {
    const timeout = Duration(seconds: 10);
    const retryDelay = Duration(milliseconds: 500);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        return apnsToken;
      }

      await Future.delayed(retryDelay);
    }

    return null;
  }
}
