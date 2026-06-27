import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/tarot_functions_client.dart';
import '../auth/user_profile_contract.dart';
import '../readings/tarot_service.dart';

class ArisChatHistoryEntry {
  const ArisChatHistoryEntry({required this.role, required this.text});

  final String role;
  final String text;

  bool get isUser => role == 'user';

  Map<String, dynamic> toMap() => {'role': role, 'text': text};
}

enum ArisSessionCategory { tarot, coffee, palm, numerology }

class ArisSessionRecord {
  const ArisSessionRecord({
    required this.sessionId,
    required this.cardName,
    required this.cardNames,
    required this.openingMessage,
    required this.recentMessages,
    required this.updatedAt,
    this.day,
    this.mode,
    this.persona,
    this.coffeeReadingId,
    this.categoryName,
  });

  final String sessionId;
  final String cardName;
  final List<String> cardNames;
  final String openingMessage;
  final List<ArisChatHistoryEntry> recentMessages;
  final DateTime? updatedAt;
  final String? day;
  final String? mode;
  final String? persona;
  final String? coffeeReadingId;
  final String? categoryName;

  bool get isSpread => cardNames.length > 1;

  ArisSessionCategory get category {
    final normalizedMode = (mode ?? '').trim();
    final normalizedPersona = (persona ?? '').trim();
    final normalizedCoffeeReadingId = (coffeeReadingId ?? '').trim();
    final normalizedCategory = (categoryName ?? '').trim();
    final normalizedCardName = cardName.trim().toLowerCase();
    if (normalizedMode == 'palmReading' ||
        normalizedCategory == 'palm' ||
        normalizedCardName == 'palm') {
      return ArisSessionCategory.palm;
    }
    if (normalizedMode == 'numerologyReading' ||
        normalizedCategory == 'numerology' ||
        normalizedCardName == 'numerology') {
      return ArisSessionCategory.numerology;
    }
    if (normalizedMode == 'coffeeReading' ||
        normalizedCategory == 'coffee' ||
        normalizedPersona == 'madamAris' ||
        normalizedCoffeeReadingId.isNotEmpty ||
        normalizedCardName.contains('kahve') ||
        normalizedCardName.contains('coffee') ||
        normalizedCardName.contains('madam aris')) {
      return ArisSessionCategory.coffee;
    }
    return ArisSessionCategory.tarot;
  }

  String get titleLabel =>
      isSpread ? cardNames.join(' · ') : (cardName.isNotEmpty ? cardName : '—');

  String get preview {
    if (openingMessage.trim().isNotEmpty) {
      return _clip(openingMessage, 140);
    }
    final last = recentMessages.reversed.firstWhere(
      (m) => m.text.trim().isNotEmpty,
      orElse: () => const ArisChatHistoryEntry(role: 'assistant', text: ''),
    );
    return _clip(last.text, 140);
  }

  int get messageCount =>
      recentMessages.length + (openingMessage.isNotEmpty ? 1 : 0);

  List<DrawnTarotCard> toDrawnCards() {
    final names = cardNames.isNotEmpty
        ? cardNames
        : (cardName.isNotEmpty ? [cardName] : const <String>[]);
    return names.map(_drawnCardForName).toList(growable: false);
  }

  static DrawnTarotCard _drawnCardForName(String name) {
    final card = TarotService.cardForDisplayName(name);
    final cachedUrl =
        TarotService.cachedUrlForIndex(card.index) ??
        TarotService.assetPathForIndex(card.index);
    return DrawnTarotCard(card: card, imageUrl: cachedUrl);
  }

  static String _clip(String value, int maxChars) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length <= maxChars) return trimmed;
    return '${trimmed.substring(0, maxChars).trim()}…';
  }

  factory ArisSessionRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ArisSessionRecord.fromMap(
      sessionId: doc.id,
      data: doc.data() ?? const <String, dynamic>{},
    );
  }

  factory ArisSessionRecord.fromMap({
    required String sessionId,
    required Map<String, dynamic> data,
  }) {
    final cardNamesRaw = data['cardNames'];
    final cardNames = cardNamesRaw is List
        ? cardNamesRaw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];
    final cardName = (data['cardName'] as String?)?.trim() ?? '';
    final openingMessage = (data['openingMessage'] as String?)?.trim() ?? '';
    final recentRaw = data['recentMessages'];
    final recentMessages = <ArisChatHistoryEntry>[];
    if (recentRaw is List) {
      for (final item in recentRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final text = (map['text'] as String?)?.trim() ?? '';
        if (text.isEmpty) continue;
        final role = map['role'] == 'user' ? 'user' : 'assistant';
        recentMessages.add(ArisChatHistoryEntry(role: role, text: text));
      }
    }

    final updatedAtMs = data['updatedAtMs'] ?? data['updatedAt'];
    DateTime? updatedAt;
    if (updatedAtMs is num && updatedAtMs > 0) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs.toInt());
    } else {
      updatedAt =
          _timestamp(data['updatedAt']) ?? _timestamp(data['createdAt']);
    }

    return ArisSessionRecord(
      sessionId: sessionId,
      cardName: cardName,
      cardNames: cardNames,
      openingMessage: openingMessage,
      recentMessages: recentMessages,
      updatedAt: updatedAt,
      day: (data['day'] as String?)?.trim(),
      mode: (data['mode'] as String?)?.trim(),
      persona: (data['persona'] as String?)?.trim(),
      coffeeReadingId: (data['coffeeReadingId'] as String?)?.trim(),
      categoryName: (data['category'] as String?)?.trim(),
    );
  }

  bool get hasHistory => openingMessage.isNotEmpty || recentMessages.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId,
    'cardName': cardName,
    'cardNames': cardNames,
    'openingMessage': openingMessage,
    'recentMessages': recentMessages.map((message) => message.toMap()).toList(),
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
    'day': day,
    'mode': mode,
    'persona': persona,
    'coffeeReadingId': coffeeReadingId,
    'category': categoryName,
  };

  ArisSessionRecord withFallbackMetadata(ArisSessionRecord fallback) {
    return ArisSessionRecord(
      sessionId: sessionId,
      cardName: cardName,
      cardNames: cardNames,
      openingMessage: openingMessage,
      recentMessages: recentMessages,
      updatedAt: updatedAt,
      day: day ?? fallback.day,
      mode: mode ?? fallback.mode,
      persona: persona ?? fallback.persona,
      coffeeReadingId: coffeeReadingId ?? fallback.coffeeReadingId,
      categoryName: categoryName ?? fallback.categoryName,
    );
  }

  static DateTime? _timestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

class ArisSessionService {
  ArisSessionService({
    FirebaseFirestore? firestore,
    TarotFunctionsClient? functionsClient,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functionsClient = functionsClient ?? TarotFunctionsClient();

  final FirebaseFirestore _firestore;
  final TarotFunctionsClient _functionsClient;

  static const int _sessionQueryLimit = 120;
  static const int _maxListedSessions = 80;

  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) {
    return _firestore
        .collection(UserProfileContract.usersCollection)
        .doc(uid)
        .collection('aris_sessions');
  }

  static List<ArisSessionRecord> mapAndSortSessions(
    Iterable<ArisSessionRecord> sessions,
  ) {
    final list = sessions.where((session) => session.hasHistory).toList();
    list.sort((a, b) {
      final aMs = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final bMs = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMs.compareTo(aMs);
    });
    if (list.length <= _maxListedSessions) return list;
    return list.take(_maxListedSessions).toList(growable: false);
  }

  static List<ArisSessionRecord> mergeSessions(
    List<ArisSessionRecord> primary,
    List<ArisSessionRecord> secondary,
  ) {
    final byId = <String, ArisSessionRecord>{};
    for (final session in [...primary, ...secondary]) {
      final existing = byId[session.sessionId];
      if (existing == null) {
        byId[session.sessionId] = session;
        continue;
      }
      final existingMs = existing.updatedAt?.millisecondsSinceEpoch ?? 0;
      final sessionMs = session.updatedAt?.millisecondsSinceEpoch ?? 0;
      if (sessionMs >= existingMs) {
        byId[session.sessionId] = session.withFallbackMetadata(existing);
      } else {
        byId[session.sessionId] = existing.withFallbackMetadata(session);
      }
    }
    return mapAndSortSessions(byId.values);
  }

  /// Real-time list; client-side sort (no composite index).
  Stream<List<ArisSessionRecord>> watchSessions(String uid) {
    return _sessionsRef(uid).limit(_sessionQueryLimit).snapshots().map((
      snapshot,
    ) {
      return mapAndSortSessions(snapshot.docs.map(ArisSessionRecord.fromDoc));
    });
  }

  static bool _isCallableUnavailable(Object error) {
    if (error is FirebaseFunctionsException) {
      final code = error.code.toLowerCase();
      return code == 'not-found' || code == 'unavailable';
    }
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();
      return code.contains('not-found') ||
          message.contains('not_found') ||
          message.contains('not-found');
    }
    final text = error.toString().toLowerCase();
    return text.contains('not-found') || text.contains('not_found');
  }

  /// One-shot Firestore read (works without Cloud Functions deploy).
  Future<List<ArisSessionRecord>> fetchSessionsFromFirestore(String uid) async {
    final snap = await _sessionsRef(uid).limit(_sessionQueryLimit).get();
    return mapAndSortSessions(snap.docs.map(ArisSessionRecord.fromDoc));
  }

  Future<List<ArisSessionRecord>> _fetchSessionsFromCallable() async {
    final data = await _functionsClient.listArisSessions();
    final raw = data['sessions'];
    if (raw is! List) return const <ArisSessionRecord>[];

    final sessions = <ArisSessionRecord>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final sessionId = (map['sessionId'] as String?)?.trim() ?? '';
      if (sessionId.isEmpty) continue;
      sessions.add(ArisSessionRecord.fromMap(sessionId: sessionId, data: map));
    }
    return mapAndSortSessions(sessions);
  }

  /// Callable when deployed; otherwise reads Firestore directly.
  Future<List<ArisSessionRecord>> fetchSessions(String uid) async {
    try {
      return await _fetchSessionsFromCallable();
    } catch (error, stackTrace) {
      if (!_isCallableUnavailable(error)) rethrow;
      if (kDebugMode) {
        debugPrint('listArisSessions unavailable, using Firestore: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return fetchSessionsFromFirestore(uid);
    }
  }

  Future<ArisSessionRecord?> fetchSession({
    required String uid,
    required String sessionId,
  }) async {
    try {
      final doc = await _sessionsRef(uid).doc(sessionId).get();
      if (!doc.exists) return null;
      final record = ArisSessionRecord.fromDoc(doc);
      if (!record.hasHistory) return null;
      return record;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('fetchSession Firestore failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    final sessions = await fetchSessions(uid);
    for (final session in sessions) {
      if (session.sessionId == sessionId) return session;
    }
    return null;
  }
}

/// Unique Firestore document id per card draw / spread.
String newArisSessionId({String prefix = 'aris'}) {
  final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final micro = (DateTime.now().microsecondsSinceEpoch % 46656).toRadixString(
    36,
  );
  final raw = '${prefix}_${stamp}_$micro';
  return raw.length <= 48 ? raw : raw.substring(0, 48);
}
