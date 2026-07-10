import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/auth/user_profile_contract.dart';

typedef UserProfileSnapshot = DocumentSnapshot<Map<String, dynamic>>;

/// Tüm ekranların aynı kullanıcı dokümanını tek bir Firestore dinleyicisiyle
/// paylaşmasını sağlar. Yeni abonelere önbellekteki son değeri hemen verir,
/// böylece her bölüm için ayrı cache→sunucu flaşı yaşanmaz.
class UserProfileStore {
  UserProfileStore._();

  static final UserProfileStore instance = UserProfileStore._();

  String? _uid;
  UserProfileSnapshot? _latest;
  StreamController<UserProfileSnapshot>? _controller;
  StreamSubscription<UserProfileSnapshot>? _sub;

  Stream<UserProfileSnapshot> watch(String uid) {
    if (_uid != uid) {
      _uid = uid;
      _latest = null;
      _sub?.cancel();
      _controller?.close();

      final controller = StreamController<UserProfileSnapshot>.broadcast();
      _controller = controller;
      _sub = FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(uid)
          .snapshots()
          .listen(
            (snap) {
              _latest = snap;
              if (!controller.isClosed) controller.add(snap);
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!controller.isClosed) {
                controller.addError(error, stackTrace);
              }
            },
          );
    }

    final controller = _controller!;
    final cached = _latest;
    return () async* {
      if (cached != null) yield cached;
      yield* controller.stream;
    }();
  }
}
