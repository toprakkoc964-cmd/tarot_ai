import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_entitlements.dart';

class EntitlementService {
  EntitlementService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Map<String, UserEntitlements> _cache = {};

  UserEntitlements? cachedUserEntitlements(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return null;
    return _cache[normalizedUid];
  }

  Stream<UserEntitlements> watchUserEntitlements(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return Stream.value(UserEntitlements.empty());
    }

    return _firestore.collection('users').doc(normalizedUid).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      final entitlements = data == null
          ? UserEntitlements.empty()
          : UserEntitlements.fromUserMap(data);
      _cache[normalizedUid] = entitlements;
      return entitlements;
    });
  }
}
