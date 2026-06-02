import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/user_profile_contract.dart';
import '../readings/tarot_service.dart';

class ArisChatHistoryEntry {
  const ArisChatHistoryEntry({
    required this.role,
    required this.text,
  });

  final String role;
  final String text;

  bool get isUser => role == 'user';
}

class ArisSessionRecord {
  const ArisSessionRecord({
    required this.sessionId,
    required this.cardName,
    required this.cardNames,
    required this.openingMessage,
    required this.recentMessages,
    required this.updatedAt,
    this.day,
  });

  final String sessionId;
  final String cardName;
  final List<String> cardNames;
  final String openingMessage;
  final List<ArisChatHistoryEntry> recentMessages;
  final DateTime? updatedAt;
  final String? day;

  bool get isSpread => cardNames.length > 1;

  String get titleLabel =>
      isSpread ? cardNames.join(' · ') : (cardName.isNotEmpty ? cardName : '—');

  String get preview {
    if (openingMessage.trim().isNotEmpty) {
      return _clip(openingMessage, 140);
    }
    final last = recentMessages.reversed
        .firstWhere(
          (m) => m.text.trim().isNotEmpty,
          orElse: () => const ArisChatHistoryEntry(role: 'assistant', text: ''),
        );
    return _clip(last.text, 140);
  }

  int get messageCount => recentMessages.length + (openingMessage.isNotEmpty ? 1 : 0);

  List<DrawnTarotCard> toDrawnCards() {
    final names = cardNames.isNotEmpty
        ? cardNames
        : (cardName.isNotEmpty ? [cardName] : const <String>[]);
    return names.map(_drawnCardForName).toList(growable: false);
  }

  static DrawnTarotCard _drawnCardForName(String name) {
    final match = TarotService.majorArcana.where(
      (card) => card.displayName.toLowerCase() == name.trim().toLowerCase(),
    );
    final card = match.isNotEmpty ? match.first : TarotService.majorArcana.first;
    return DrawnTarotCard(card: card, imageUrl: '');
  }

  static String _clip(String value, int maxChars) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length <= maxChars) return trimmed;
    return '${trimmed.substring(0, maxChars).trim()}…';
  }

  factory ArisSessionRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final cardNamesRaw = data['cardNames'];
    final cardNames = cardNamesRaw is List
        ? cardNamesRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final cardName = (data['cardName'] as String?)?.trim() ?? '';
    final openingMessage = (data['openingMessage'] as String?)?.trim() ?? '';
    final recentRaw = data['recentMessages'];
    final recentMessages = <ArisChatHistoryEntry>[];
    if (recentRaw is List) {
      for (final item in recentRaw) {
        if (item is! Map) continue;
        final text = (item['text'] as String?)?.trim() ?? '';
        if (text.isEmpty) continue;
        final role = item['role'] == 'user' ? 'user' : 'assistant';
        recentMessages.add(ArisChatHistoryEntry(role: role, text: text));
      }
    }

    return ArisSessionRecord(
      sessionId: doc.id,
      cardName: cardName,
      cardNames: cardNames,
      openingMessage: openingMessage,
      recentMessages: recentMessages,
      updatedAt: _timestamp(data['updatedAt']) ?? _timestamp(data['createdAt']),
      day: (data['day'] as String?)?.trim(),
    );
  }

  static DateTime? _timestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

class ArisSessionService {
  ArisSessionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<ArisSessionRecord>> watchSessions(String uid) {
    return _firestore
        .collection(UserProfileContract.usersCollection)
        .doc(uid)
        .collection('aris_sessions')
        .orderBy('updatedAt', descending: true)
        .limit(60)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(ArisSessionRecord.fromDoc)
          .where((session) => session.openingMessage.isNotEmpty)
          .toList(growable: false);
    });
  }

  Future<ArisSessionRecord?> fetchSession({
    required String uid,
    required String sessionId,
  }) async {
    final doc = await _firestore
        .collection(UserProfileContract.usersCollection)
        .doc(uid)
        .collection('aris_sessions')
        .doc(sessionId)
        .get();
    if (!doc.exists) return null;
    final record = ArisSessionRecord.fromDoc(doc);
    if (record.openingMessage.isEmpty) return null;
    return record;
  }
}
