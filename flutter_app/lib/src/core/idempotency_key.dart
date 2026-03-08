import 'dart:math';

String createIdempotencyKey() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final rand = Random.secure().nextInt(1 << 32).toRadixString(16);
  return 'idem_${now}_$rand';
}
