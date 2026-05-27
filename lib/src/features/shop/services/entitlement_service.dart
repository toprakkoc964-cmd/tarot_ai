import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_entitlements.dart';

class EntitlementService {
  EntitlementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<UserEntitlements> watchUserEntitlements(String uid) {
    if (uid.trim().isEmpty) {
      return Stream.value(UserEntitlements.empty());
    }

    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return UserEntitlements.empty();
      return UserEntitlements.fromUserMap(data);
    });
  }
}
