import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/app_language.dart';
import '../../../core/tarot_functions_client.dart';
import '../models/palmistry_result.dart';
import 'i_palmistry_service.dart';
import 'palmistry_analysis_exception.dart';

class CloudPalmistryService implements IPalmistryService {
  CloudPalmistryService({TarotFunctionsClient? functionsClient})
      : _functionsClient = functionsClient ?? TarotFunctionsClient();

  final TarotFunctionsClient _functionsClient;

  @override
  Future<PalmistryResult> analyzePalm(
    File image, {
    bool preValidated = false,
  }) async {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw const PalmistryAnalysisException('INVALID_PALM_IMAGE_INPUT');
    }

    try {
      final response = await _functionsClient.analyzePalmReading(
        imageBase64: base64Encode(bytes),
        lang: _activeLanguage(),
        mimeType: 'image/jpeg',
        preValidated: preValidated,
      );
      final result = PalmistryResult.fromMap(response);
      if (!result.isValid &&
          result.reading.mindLine.trim().isEmpty &&
          result.reading.heartLine.trim().isEmpty &&
          result.reading.lifeEnergy.trim().isEmpty) {
        throw const PalmistryAnalysisException('IMAGE_UNREADABLE');
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      final code = (error.message ?? error.code).trim();
      throw PalmistryAnalysisException(
        code.isEmpty ? 'PALM_ANALYSIS_FAILED' : code,
      );
    }
  }

  String _activeLanguage() => AppLanguage.forAi();
}
