import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tarot_ai/src/features/coffee_reading/models/coffee_photo_step.dart';
import 'package:tarot_ai/src/features/coffee_reading/services/coffee_residue_detection_service.dart';

void main() {
  late Directory tempDirectory;
  late CoffeeResidueDetectionService service;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('coffee_roi_test_');
    service = CoffeeResidueDetectionService();
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('ignores a dark outer background outside the cup ROI', () async {
    final image = img.Image(width: 100, height: 100);
    img.fill(image, color: img.ColorRgb8(240, 240, 240));
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (x < 8 || y < 8 || x >= 92 || y >= 92) {
          image.setPixelRgb(x, y, 20, 18, 16);
        }
      }
    }

    final metrics = await service.analyze(
      await _writeImage(tempDirectory, image, 'outer_background.jpg'),
      step: CoffeePhotoStep.cupInside,
    );

    expect(metrics.darkResidueRatio, lessThan(0.03));
    expect(metrics.hasResidue, isFalse);
  });

  test('detects coffee-like texture inside the center ROI', () async {
    final image = img.Image(width: 100, height: 100);
    img.fill(image, color: img.ColorRgb8(235, 235, 230));
    for (var y = 26; y < 74; y++) {
      for (var x = 26; x < 74; x++) {
        if ((x + y).isEven) {
          image.setPixelRgb(x, y, 55, 42, 30);
        }
      }
    }

    final metrics = await service.analyze(
      await _writeImage(tempDirectory, image, 'center_residue.jpg'),
      step: CoffeePhotoStep.cupInside,
    );

    expect(metrics.darkResidueRatio, greaterThan(0.2));
    expect(metrics.hasResidue, isTrue);
  });
}

Future<File> _writeImage(Directory directory, img.Image image, String name) {
  final file = File('${directory.path}/$name');
  return file.writeAsBytes(img.encodeJpg(image, quality: 95));
}
