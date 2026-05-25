import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<File> compressPalmImage(File file) async {
  const targetBytes = 1024 * 1024;
  const qualities = [85, 75, 65];

  try {
    var source = file;
    final tempDir = await getTemporaryDirectory();

    for (final quality in qualities) {
      final outputPath = p.join(
        tempDir.path,
        'palm_${DateTime.now().millisecondsSinceEpoch}_q$quality.jpg',
      );
      final compressed = await FlutterImageCompress.compressAndGetFile(
        source.path,
        outputPath,
        minWidth: 1080,
        minHeight: 1080,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (compressed == null) continue;
      final compressedFile = File(compressed.path);
      if (await compressedFile.length() <= targetBytes) {
        return compressedFile;
      }
      source = compressedFile;
    }

    return source;
  } catch (e, st) {
    debugPrint('Palm image compression failed: $e');
    debugPrintStack(stackTrace: st);
    return file;
  }
}
