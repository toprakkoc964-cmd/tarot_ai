import 'coffee_photo_step.dart';
import 'coffee_validation_failure_reason.dart';

class CoffeeStepValidationResult {
  const CoffeeStepValidationResult({
    required this.isValid,
    required this.reason,
  });

  final bool isValid;
  final String reason;

  factory CoffeeStepValidationResult.fromMap(Map<String, dynamic> map) {
    return CoffeeStepValidationResult(
      isValid: map['isValid'] == true,
      reason: (map['reason'] as String?)?.trim() ?? '',
    );
  }
}

class CoffeeAiValidationResponse {
  const CoffeeAiValidationResponse({
    required this.isValid,
    required this.confidence,
    required this.failureStep,
    required this.failureReason,
    required this.userMessage,
    required this.detectedIssues,
    required this.stepResults,
  });

  final bool isValid;
  final double confidence;
  final CoffeePhotoStep? failureStep;
  final CoffeeValidationFailureReason? failureReason;
  final String? userMessage;
  final List<String> detectedIssues;
  final Map<CoffeePhotoStep, CoffeeStepValidationResult> stepResults;

  factory CoffeeAiValidationResponse.fromMap(Map<String, dynamic> map) {
    final stepResultsRaw =
        Map<String, dynamic>.from(map['stepResults'] as Map? ?? const {});
    final stepResults = <CoffeePhotoStep, CoffeeStepValidationResult>{};
    for (final step in CoffeePhotoStep.values) {
      final raw = stepResultsRaw[step.metadataKey];
      if (raw is Map) {
        stepResults[step] =
            CoffeeStepValidationResult.fromMap(Map<String, dynamic>.from(raw));
      }
    }

    CoffeePhotoStep? failureStep;
    final failureStepRaw = map['failureStep'] as String?;
    if (failureStepRaw != null) {
      for (final step in CoffeePhotoStep.values) {
        if (step.metadataKey == failureStepRaw) {
          failureStep = step;
          break;
        }
      }
    }

    final failureReasonRaw = map['failureReason'] as String?;
    final failureReason = failureReasonRaw == null
        ? null
        : CoffeeValidationFailureReason.fromBackend(failureReasonRaw);

    return CoffeeAiValidationResponse(
      isValid: map['isValid'] == true,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      failureStep: failureStep,
      failureReason: failureReason,
      userMessage: (map['userMessage'] as String?)?.trim(),
      detectedIssues:
          (map['detectedIssues'] as List?)?.whereType<String>().toList() ??
              const [],
      stepResults: stepResults,
    );
  }
}
