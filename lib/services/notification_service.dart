import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../src/core/notification_service.dart' as app_notifications;
import '../src/core/utils/notification_translator.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const AndroidNotificationChannel _dailyReadingsChannel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'Daily Readings',
    description: 'Daily tarot and spiritual reminder notifications.',
    importance: Importance.high,
  );

  static const DarwinNotificationCategory _dailyCategory =
      DarwinNotificationCategory('daily_readings');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    await _ensureInitialized();

    await scheduleMorningNotifications();
    await scheduleMiddayReminders();
  }

  Future<void> initializeForBackgroundMessages() async {
    await _ensureInitialized();
  }

  Future<void> scheduleMorningNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    final hasQueuedDailyTarot = pending.any(
      (request) => request.payload?.startsWith('daily_tarot:') ?? false,
    );
    if (hasQueuedDailyTarot) return;

    final languageCode = _resolveLanguageCode();
    final title = await NotificationTranslator.getTranslation(
      languageCode,
      'daily_tarot',
      'title',
    );
    final body = await NotificationTranslator.getTranslation(
      languageCode,
      'daily_tarot',
      'body',
    );

    final random = Random();
    final now = tz.TZDateTime.now(tz.local);
    var scheduledCount = 0;
    var dayOffset = 0;

    while (scheduledCount < 7) {
      final baseDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + dayOffset,
        7,
      );
      final randomMinutes = random.nextInt(121);
      final scheduledAt = baseDate.add(Duration(minutes: randomMinutes));

      dayOffset += 1;
      if (!scheduledAt.isAfter(now)) {
        continue;
      }

      await _scheduleNotification(
        id: _morningNotificationId(scheduledAt),
        type: 'daily_tarot',
        title: title,
        body: body,
        scheduledAt: scheduledAt,
      );
      scheduledCount += 1;
    }
  }

  Future<void> scheduleMiddayReminders() async {
    final pending = await _plugin.pendingNotificationRequests();
    final hasQueuedReminders = pending.any(
      (request) => request.payload?.startsWith('tarot_reminder:') ?? false,
    );
    if (hasQueuedReminders) return;

    final languageCode = _resolveLanguageCode();
    final title = await NotificationTranslator.getTranslation(
      languageCode,
      'tarot_reminder',
      'title',
    );
    final body = await NotificationTranslator.getTranslation(
      languageCode,
      'tarot_reminder',
      'body',
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledCount = 0;
    var dayOffset = 0;

    while (scheduledCount < 7) {
      final scheduledAt = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + dayOffset,
        11,
        30,
      );
      dayOffset += 1;
      if (!scheduledAt.isAfter(now)) {
        continue;
      }

      await _scheduleNotification(
        id: _middayReminderId(scheduledAt),
        type: 'tarot_reminder',
        title: title,
        body: body,
        scheduledAt: scheduledAt,
      );
      scheduledCount += 1;
    }
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  Future<void> requestPermissions() async {
    await _requestPermissions();
  }

  Future<void> printPendingNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    if (pending.isEmpty) {
      debugPrint('No pending notifications in queue.');
      return;
    }

    for (final request in pending) {
      final scheduledAt = _scheduledAtFromPayload(request.payload);
      debugPrint(
        'Pending notification -> '
        'id: ${request.id}, '
        'title: ${request.title ?? 'unknown'}, '
        'scheduledAt: ${scheduledAt?.toIso8601String() ?? 'unknown'}, '
        'payload: ${request.payload ?? 'none'}',
      );
    }
  }

  Future<void> onDailyCardDrawn(String cardName, String langCode) async {
    final now = tz.TZDateTime.now(tz.local);
    await _plugin.cancel(id: _middayReminderId(now));

    final title = await NotificationTranslator.getTranslation(
      langCode,
      'arcana_chat',
      'title',
    );
    final body = await NotificationTranslator.getTranslation(
      langCode,
      'arcana_chat',
      'body',
      args: {'cardName': cardName},
    );

    final scheduledAt = _randomEveningTime(now);
    if (scheduledAt == null) {
      debugPrint(
          'Arcana chat notification skipped: evening window has passed.');
      return;
    }

    await _scheduleNotification(
      id: _arcanaChatId(now),
      type: 'arcana_chat',
      title: title,
      body: body,
      scheduledAt: scheduledAt,
    );
  }

  Future<void> _configureNotificationChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_dailyReadingsChannel);
  }

  Future<void> _requestPermissions() async {
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macOsPlugin = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    await macOsPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> showNotificationFromRemoteMessage(RemoteMessage message) async {
    await _ensureInitialized();

    final data = message.data;
    final langCode =
        (data['lang']?.toString().trim().toLowerCase().isNotEmpty ?? false)
            ? data['lang']!.toString().trim().toLowerCase()
            : _resolveLanguageCode();
    final type = data['type']?.toString().trim() ?? 'daily_tarot';

    final title = _resolvedMessageTitle(message, data, langCode, type);
    final body = await _resolvedMessageBody(message, data, langCode, type);
    final storedMessageId =
        message.messageId ??
        '${type}_${DateTime.now().microsecondsSinceEpoch}';

    await _plugin.show(
      id: _backgroundNotificationId(),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'Daily Readings',
          channelDescription:
              'Daily tarot and spiritual reminder notifications.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'daily_readings',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: data.isEmpty ? null : data.toString(),
    );

    await app_notifications.NotificationService.instance.storeNotification(
      id: storedMessageId,
      title: title,
      body: body,
      source: 'background',
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String type,
    required String title,
    required String body,
    required tz.TZDateTime scheduledAt,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledAt,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'Daily Readings',
          channelDescription:
              'Daily tarot and spiritual reminder notifications.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'daily_readings',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: '$type:${scheduledAt.toIso8601String()}',
    );
  }

  Future<void> _ensureInitialized() async {
    await _configureLocalTimezone();

    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [_dailyCategory],
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: settings);
    await _configureNotificationChannels();
    _initialized = true;
  }

  Future<void> _configureLocalTimezone() async {
    tz.initializeTimeZones();

    final current = DateTime.now();
    final offset = current.timeZoneOffset;
    final currentZoneName = current.timeZoneName.trim();
    final candidates = <String>{
      if (currentZoneName.isNotEmpty) currentZoneName,
      ...?_mappedTimezoneCandidates(currentZoneName, offset),
    };

    for (final candidate in candidates) {
      try {
        tz.setLocalLocation(tz.getLocation(candidate));
        return;
      } catch (_) {
        // Try the next candidate until we find a valid IANA zone.
      }
    }

    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  Set<String>? _mappedTimezoneCandidates(String zoneName, Duration offset) {
    final normalized = zoneName.toUpperCase();
    final offsetMap = <String, String>{
      'TRT': 'Europe/Istanbul',
      'TURKEY TIME': 'Europe/Istanbul',
      'GMT+03:00': 'Europe/Istanbul',
      'UTC+03:00': 'Europe/Istanbul',
      'EEST': 'Europe/Athens',
      'EET': 'Europe/Athens',
      'BST': 'Europe/London',
      'GMT': 'Europe/London',
      'UTC': 'UTC',
      'CET': 'Europe/Paris',
      'CEST': 'Europe/Paris',
      'EST': 'America/New_York',
      'EDT': 'America/New_York',
      'CST': 'America/Chicago',
      'CDT': 'America/Chicago',
      'MST': 'America/Denver',
      'MDT': 'America/Denver',
      'PST': 'America/Los_Angeles',
      'PDT': 'America/Los_Angeles',
    };

    final candidates = <String>{};
    final mapped = offsetMap[normalized];
    if (mapped != null) {
      candidates.add(mapped);
    }

    final fallbackByOffset = <Duration, String>{
      const Duration(hours: 3): 'Europe/Istanbul',
      const Duration(hours: 2): 'Europe/Athens',
      const Duration(hours: 1): 'Europe/Paris',
      Duration.zero: 'UTC',
      const Duration(hours: -4): 'America/New_York',
      const Duration(hours: -5): 'America/Chicago',
      const Duration(hours: -6): 'America/Denver',
      const Duration(hours: -7): 'America/Los_Angeles',
      const Duration(hours: -8): 'America/Anchorage',
      const Duration(hours: -10): 'Pacific/Honolulu',
    };

    final fallback = fallbackByOffset[offset];
    if (fallback != null) {
      candidates.add(fallback);
    }

    return candidates;
  }

  String _resolveLanguageCode() {
    final languageCode = PlatformDispatcher.instance.locale.languageCode.trim();
    if (languageCode.isEmpty) return 'en';
    if (languageCode.toLowerCase() == 'tr') return 'tr';
    return 'en';
  }

  int _morningNotificationId(tz.TZDateTime date) {
    return (date.year * 10000) + (date.month * 100) + date.day;
  }

  int _middayReminderId(tz.TZDateTime date) {
    return _morningNotificationId(date) * 100 + 1;
  }

  int _arcanaChatId(tz.TZDateTime date) {
    return _morningNotificationId(date) * 100 + 2;
  }

  int _backgroundNotificationId() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  DateTime? _scheduledAtFromPayload(String? payload) {
    if (payload == null || !payload.contains(':')) return null;
    final parts = payload.split(':');
    if (parts.length < 2) return null;
    final rawDate = parts.sublist(1).join(':');
    return DateTime.tryParse(rawDate);
  }

  tz.TZDateTime? _randomEveningTime(tz.TZDateTime now) {
    final random = Random();
    final eveningStart = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      19,
    );

    final candidates = List<tz.TZDateTime>.generate(
      121,
      (index) => eveningStart.add(Duration(minutes: index)),
    ).where((candidate) => candidate.isAfter(now)).toList(growable: false);

    if (candidates.isEmpty) {
      return null;
    }

    return candidates[random.nextInt(candidates.length)];
  }

  String _resolvedMessageTitle(
    RemoteMessage message,
    Map<String, dynamic> data,
    String langCode,
    String type,
  ) {
    final directTitle = data['title']?.toString().trim();
    if (directTitle != null && directTitle.isNotEmpty) {
      return directTitle;
    }

    final notificationTitle = message.notification?.title?.trim();
    if (notificationTitle != null && notificationTitle.isNotEmpty) {
      return notificationTitle;
    }

    switch (type) {
      case 'tarot_reminder':
        return langCode == 'tr'
            ? 'Kartin Seni Bekliyor 🔮'
            : 'Your Card Awaits 🔮';
      case 'arcana_chat':
        return langCode == 'tr' ? 'Arcana Fisildiyor...' : 'Arcana Whispers...';
      case 'daily_nudge':
      case 'daily_tarot':
      default:
        return langCode == 'tr'
            ? 'Gunun Kozmik Mesaji 🌟'
            : "Today's Cosmic Message 🌟";
    }
  }

  Future<String> _resolvedMessageBody(
    RemoteMessage message,
    Map<String, dynamic> data,
    String langCode,
    String type,
  ) async {
    final directBody = data['body']?.toString().trim();
    if (directBody != null && directBody.isNotEmpty) {
      return directBody;
    }

    final notificationBody = message.notification?.body?.trim();
    if (notificationBody != null && notificationBody.isNotEmpty) {
      return notificationBody;
    }

    final normalizedType = type == 'daily_nudge' ? 'daily_tarot' : type;
    final args = <String, String>{
      if (data['cardName']?.toString().trim().isNotEmpty ?? false)
        'cardName': data['cardName'].toString().trim(),
    };

    final translated = await NotificationTranslator.getTranslation(
      langCode,
      normalizedType,
      'body',
      args: args,
    );
    return translated.isEmpty ? 'Cosmic Message ✨' : translated;
  }
}
