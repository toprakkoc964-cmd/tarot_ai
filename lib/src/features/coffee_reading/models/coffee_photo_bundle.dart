import 'dart:io';

import 'coffee_photo_step.dart';
import 'coffee_validation_result.dart';

class CoffeePhotoItem {
  const CoffeePhotoItem({
    required this.step,
    required this.file,
    required this.validationResult,
    required this.tempFiles,
  });

  final CoffeePhotoStep step;
  final File file;
  final CoffeeValidationResult validationResult;
  final List<File> tempFiles;
}

class CoffeePhotoBundle {
  const CoffeePhotoBundle({
    required this.items,
  });

  const CoffeePhotoBundle.empty() : items = const {};

  final Map<CoffeePhotoStep, CoffeePhotoItem> items;

  CoffeePhotoItem? operator [](CoffeePhotoStep step) => items[step];

  File? get cupInside => items[CoffeePhotoStep.cupInside]?.file;
  File? get saucer => items[CoffeePhotoStep.saucer]?.file;
  File? get cupSide => items[CoffeePhotoStep.cupSide]?.file;

  bool get isComplete {
    return CoffeePhotoStep.values.every(items.containsKey);
  }

  List<File> get imageFiles {
    return CoffeePhotoStep.values
        .map((step) => items[step]?.file)
        .whereType<File>()
        .toList(growable: false);
  }

  Map<CoffeePhotoStep, CoffeeValidationResult> get validations {
    return {
      for (final entry in items.entries)
        entry.key: entry.value.validationResult,
    };
  }

  List<File> get ownedTempFiles {
    return items.values
        .expand((item) => item.tempFiles)
        .toList(growable: false);
  }

  CoffeePhotoBundle put(CoffeePhotoItem item) {
    return CoffeePhotoBundle(
      items: {
        ...items,
        item.step: item,
      },
    );
  }
}
