import 'dart:io';

import 'package:flutter/foundation.dart';

class CoffeeTempFileCleaner {
  Future<void> cleanup(Iterable<File> files) async {
    for (final file in files) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Coffee temp cleanup skipped: $e');
        }
      }
    }
  }
}
