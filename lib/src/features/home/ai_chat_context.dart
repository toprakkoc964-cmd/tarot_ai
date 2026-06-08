import 'dart:io';

import '../../core/app_texts.dart';
import '../coffee_reading/models/coffee_image_pipeline_result.dart';
import '../coffee_reading/models/coffee_photo_step.dart';
import '../coffee_reading/models/coffee_validation_result.dart';

enum AiPersona {
  bilgeAris,
  madamAris,
}

enum AiChatMode {
  general,
  tarotReading,
  palmReading,
  coffeeReading,
}

class AiChatContext {
  const AiChatContext({
    required this.persona,
    required this.mode,
    required this.title,
    this.imageFile,
    this.imageFiles,
    this.coffeePhotos,
    this.metadata,
    this.initialPrompt,
    this.ownsImageFile = false,
  });

  final AiPersona persona;
  final AiChatMode mode;
  final String title;
  final File? imageFile;
  final List<File>? imageFiles;
  final Map<CoffeePhotoStep, CoffeeImagePipelineResult>? coffeePhotos;
  final Map<String, dynamic>? metadata;
  final String? initialPrompt;
  final bool ownsImageFile;

  bool get isCoffeeReading => mode == AiChatMode.coffeeReading;

  List<File> get contextImageFiles {
    final files = imageFiles;
    if (files != null) return files;
    final file = imageFile;
    return file == null ? const [] : [file];
  }

  factory AiChatContext.coffeeReadingMadamAris({
    required List<File> imageFiles,
    required Map<CoffeePhotoStep, CoffeeValidationResult> validations,
    Map<CoffeePhotoStep, CoffeeImagePipelineResult>? coffeePhotos,
    String? sessionId,
    String? idempotencyKey,
  }) {
    final validationSummary = {
      for (final entry in validations.entries)
        entry.key.metadataKey: {
          'confidence': entry.value.confidence,
          'hasWarning': entry.value.hasWarning,
          'matchedLabels': entry.value.matchedLabels,
        },
    };

    return AiChatContext(
      persona: AiPersona.madamAris,
      mode: AiChatMode.coffeeReading,
      title: AppTexts.t('coffeeMadamArisTitle'),
      imageFile: imageFiles.isEmpty ? null : imageFiles.first,
      imageFiles: List<File>.unmodifiable(imageFiles),
      coffeePhotos: coffeePhotos == null
          ? null
          : Map<CoffeePhotoStep, CoffeeImagePipelineResult>.unmodifiable(
              coffeePhotos,
            ),
      ownsImageFile: true,
      metadata: {
        'source': 'coffee_reading',
        'requiredPhotoCount': 3,
        if (sessionId != null && sessionId.trim().isNotEmpty)
          'sessionId': sessionId.trim(),
        if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
          'idempotencyKey': idempotencyKey.trim(),
        'validationSummary': validationSummary,
        'createdAt': DateTime.now().toIso8601String(),
      },
      initialPrompt: '''
Sen Madam Aris adlı zarif, mistik ve bilge bir kahve falı yorumcususun.
Kullanıcının yüklediği 3 farklı kahve falı fotoğrafını birlikte yorumlarsın:
1. fincanın içi
2. fincan tabağı
3. fincanın dış görünümü

Yorumlarını eğlence ve kişisel farkındalık amacıyla yaparsın.
Tıbbi, finansal, hukuki tavsiye vermezsin.
Kesin gelecek tahmini yapmazsın.
Korkutucu, kaderci veya manipülatif ifadeler kullanmazsın.
Cevapların Türk kahvesi falı kültürüne uygun, sıcak, sezgisel, premium ve anlaşılır olmalı.
Bu 3 fotoğrafı birlikte değerlendir.
Fincanın içi, tabağı ve dış görünümü arasında sembolik bağlar kur.
Yorumu şu başlıklarla yapılandır:
1. Fincanın Genel Enerjisi
2. Telvede Beliren Semboller
3. Tabağın Taşıdığı İzler
4. Dış Görünümün Verdiği Mesaj
5. Geçmişten Gelen İz
6. Şu Anki Ruh Hali
7. Yakın Dönem Mesajı
8. Madam Aris’in Tavsiyesi
''',
    );
  }
}
