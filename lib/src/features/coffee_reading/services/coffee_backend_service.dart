import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../models/coffee_photo_step.dart';

class CoffeeBackendService {
  CoffeeBackendService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<Map<CoffeePhotoStep, String>> uploadPhotos({
    required String uid,
    required String readingId,
    required Map<CoffeePhotoStep, File> photos,
  }) async {
    final refs = <CoffeePhotoStep, String>{};
    try {
      for (final entry in photos.entries) {
        final path = 'coffee/$uid/$readingId/${entry.key.metadataKey}.jpg';
        final ref = _storage.ref(path);
        await ref.putFile(
          entry.value,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        refs[entry.key] = path;
      }
      return refs;
    } catch (_) {
      await deleteUploadedPhotos(refs.values);
      rethrow;
    }
  }

  Future<void> deleteUploadedPhotos(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        await _storage.ref(path).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
  }
}
