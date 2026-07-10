import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/function_error_codes.dart';
import '../../../core/idempotency_key.dart';
import '../../../core/theme/app_colors.dart';
import '../models/coffee_image_pipeline_result.dart';
import '../models/coffee_photo_step.dart';
import '../services/coffee_image_pipeline_service.dart';
import '../services/coffee_temp_file_cleaner.dart';
import '../../home/ai_chat_context.dart';
import '../../home/aris_session_service.dart';
import '../../home/chat_page.dart';
import '../../shop/models/user_entitlements.dart';
import '../../shop/screens/credit_purchase_sheet.dart';
import '../../shop/services/entitlement_service.dart';
import '../widgets/coffee_capture_card.dart';
import '../widgets/coffee_capture_progress.dart';
import '../widgets/coffee_source_bottom_sheet.dart';
import '../widgets/coffee_sticky_cta.dart';
import '../widgets/coffee_validation_error_dialog.dart';
import 'coffee_loading_screen.dart';

class CoffeeCaptureFlowScreen extends StatefulWidget {
  const CoffeeCaptureFlowScreen({super.key, required this.uid});

  final String uid;

  @override
  State<CoffeeCaptureFlowScreen> createState() =>
      _CoffeeCaptureFlowScreenState();
}

class _CoffeeCaptureFlowScreenState extends State<CoffeeCaptureFlowScreen> {
  final Map<CoffeePhotoStep, CoffeeImagePipelineResult> _completedSteps = {};
  final List<String> _fingerprints = [];
  final Set<CoffeePhotoStep> _backendRetrySteps = {};

  CoffeePhotoStep _activeStep = CoffeePhotoStep.cupInside;
  bool _isProcessing = false;
  bool _isAnalyzing = false;
  bool _transferredPhotoOwnership = false;
  String _overlayMessageKey = 'coffeePreparingPhoto';

  CoffeeImagePipelineService get _pipeline =>
      GetIt.I<CoffeeImagePipelineService>();
  CoffeeTempFileCleaner get _cleaner => GetIt.I<CoffeeTempFileCleaner>();
  bool get _isComplete =>
      _completedSteps.length == CoffeePhotoStep.values.length;

  @override
  void dispose() {
    if (!_transferredPhotoOwnership) {
      unawaited(
        _cleaner.cleanup(
          _completedSteps.values.expand((result) => result.tempFiles),
        ),
      );
    }
    super.dispose();
  }

  Future<void> _chooseSourceForStep(CoffeePhotoStep step) async {
    if (_isProcessing || _isAnalyzing) return;
    var shouldRetry = false;
    setState(() {
      _activeStep = step;
      _overlayMessageKey = 'coffeePreparingPhoto';
    });

    final source = await CoffeeSourceBottomSheet.show(context);
    if (source == null || !mounted) return;

    setState(() {
      _isProcessing = true;
      _overlayMessageKey = 'coffeeValidatingPhoto';
    });

    try {
      final result = await _pipeline.processImage(
        source,
        step,
        previousFingerprints: List<String>.from(_fingerprints),
      );
      if (result == null || !mounted) return;

      final previous = _completedSteps[step];
      if (previous != null) {
        final oldIndex = _fingerprints.indexOf(previous.fingerprint);
        if (oldIndex >= 0) _fingerprints.removeAt(oldIndex);
        await _cleaner.cleanup(previous.tempFiles);
      }

      final imagePath = result.compressedImage.path;
      await _cleaner.cleanup(
        result.tempFiles.where((file) => file.path != imagePath),
      );

      if (!mounted) return;
      setState(() {
        _completedSteps[step] = result;
        _fingerprints.add(result.fingerprint);
        _backendRetrySteps.remove(step);
        _activeStep = _nextIncompleteStep() ?? step;
      });
    } on CoffeePipelineException catch (error) {
      if (!mounted) return;
      shouldRetry =
          await CoffeeValidationErrorDialog.show(
            context,
            step: step,
            validationResult: error.validationResult,
          ) ==
          true;
    } catch (_) {
      if (mounted) {
        _showSnack(AppTexts.t('coffeeValidationFailed'));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
    if (shouldRetry && mounted) {
      await _chooseSourceForStep(step);
    }
  }

  CoffeePhotoStep? _nextIncompleteStep() {
    for (final step in CoffeePhotoStep.values) {
      if (!_completedSteps.containsKey(step)) return step;
    }
    return null;
  }

  Future<void> _submitForReading() async {
    if (_isAnalyzing || !_isComplete) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _overlayMessageKey = 'coffeeAnalyzingSymbols';
    });

    try {
      final photos = Map<CoffeePhotoStep, CoffeeImagePipelineResult>.from(
        _completedSteps,
      );
      final sessionId = newArisSessionId(prefix: 'coffee');
      final idempotencyKey = createIdempotencyKey();

      await Future<void>.delayed(
        const Duration(milliseconds: 1350),
      ).timeout(const Duration(seconds: 3), onTimeout: () {});

      if (!mounted) return;
      _transferredPhotoOwnership = true;
      await Navigator.of(context).pushReplacement<void, void>(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => KozmikBilgePage(
            uid: widget.uid,
            chatContext: AiChatContext.coffeeReadingMadamAris(
              imageFiles: CoffeePhotoStep.values
                  .map((step) => photos[step]?.compressedImage)
                  .whereType<File>()
                  .toList(growable: false),
              validations: {
                for (final entry in photos.entries)
                  entry.key: entry.value.validationResult,
              },
              coffeePhotos: photos,
              sessionId: sessionId,
              idempotencyKey: idempotencyKey,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 520),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.025),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
                  child: child,
                ),
              ),
            );
          },
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
      });
      if (error.message == FunctionErrorCodes.insufficientCredits) {
        _showSnack(AppTexts.t('home.cta.insufficient_credits_message'));
        unawaited(showCreditPurchaseSheet(context, uid: widget.uid));
        return;
      }
      if (error.message == FunctionErrorCodes.coffeeAnalysisInProgress) {
        _showSnack(AppTexts.t('coffeeAnalysisInProgress'));
        return;
      }
      if (error.message == FunctionErrorCodes.coffeeRateLimited) {
        _showSnack(AppTexts.t('coffeeRateLimited'));
        return;
      }
      _showSnack(AppTexts.t('coffeeValidationParseError'));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
      });
      _showSnack(AppTexts.t('coffeeValidationParseError'));
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceHigh,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing && !_isAnalyzing,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 460),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.025),
                end: Offset.zero,
              ).animate(animation),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.975, end: 1).animate(animation),
                child: child,
              ),
            ),
          );
        },
        child: _isAnalyzing
            ? CoffeeLoadingScreen(
                key: const ValueKey('coffee-loading'),
                photos: Map<CoffeePhotoStep, CoffeeImagePipelineResult>.from(
                  _completedSteps,
                ),
              )
            : Scaffold(
                key: const ValueKey('coffee-capture'),
                backgroundColor: AppColors.background,
                body: Stack(
                  children: [
                    const _CoffeeCaptureBackground(),
                    SafeArea(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          18,
                          24,
                          _isComplete ? 188 : 32,
                        ),
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () => Navigator.of(context).maybePop(),
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: AppColors.primaryPink,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  AppTexts.t('coffeeTitle'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.newsreader(
                                    color: AppColors.primaryPink,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppTexts.t('coffeeDescription'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: AppColors.secondaryLavender.withValues(
                                alpha: 0.84,
                              ),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppTexts.t('coffeeValidationCameraRecommended'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: AppColors.tertiaryGold.withValues(
                                alpha: 0.88,
                              ),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            AppTexts.t('coffeeValidationPrivacyInfo'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: AppColors.secondaryLavender.withValues(
                                alpha: 0.68,
                              ),
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${AppTexts.t('coffeeValidationLocalInfo')} ${AppTexts.t('coffeeValidationBackendInfo')}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: AppColors.secondaryLavender.withValues(
                                alpha: 0.62,
                              ),
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 22),
                          CoffeeCaptureProgress(
                            activeStep: _activeStep,
                            completedSteps: _completedSteps,
                            retrySteps: _backendRetrySteps,
                            onStepTap: (step) {
                              if (_isProcessing) return;
                              setState(() => _activeStep = step);
                            },
                          ),
                          const SizedBox(height: 24),
                          CoffeeCaptureCard(
                            step: _activeStep,
                            result: _completedSteps[_activeStep],
                            isProcessing: _isProcessing,
                            needsRetry: _backendRetrySteps.contains(
                              _activeStep,
                            ),
                            onAddPhoto: () => _chooseSourceForStep(_activeStep),
                          ),
                          const SizedBox(height: 18),
                          _CompletedSummary(
                            completedCount: _completedSteps.length,
                          ),
                        ],
                      ),
                    ),
                    if (_isComplete)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: StreamBuilder<UserEntitlements>(
                          stream: GetIt.I<EntitlementService>()
                              .watchUserEntitlements(widget.uid),
                          initialData: GetIt.I<EntitlementService>()
                              .cachedUserEntitlements(widget.uid),
                          builder: (context, snapshot) {
                            return CoffeeStickyCta(
                              onPressed: _isProcessing
                                  ? null
                                  : _submitForReading,
                              isLoading: false,
                              firstCoffeeFreeUsed:
                                  snapshot.data?.firstCoffeeFreeUsed ?? false,
                            );
                          },
                        ),
                      ),
                    if (_isProcessing)
                      _PreparingOverlay(messageKey: _overlayMessageKey),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CompletedSummary extends StatelessWidget {
  const _CompletedSummary({required this.completedCount});

  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final isComplete = completedCount == CoffeePhotoStep.values.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(
            isComplete ? Icons.auto_awesome_rounded : Icons.timelapse_rounded,
            color: isComplete ? AppColors.primaryPink : AppColors.tertiaryGold,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isComplete
                  ? AppTexts.t('coffeeAllPhotosReady')
                  : AppTexts.t(
                      'coffeeProgressHint',
                    ).replaceFirst('{count}', completedCount.toString()),
              style: GoogleFonts.manrope(
                color: AppColors.secondaryLavender.withValues(alpha: 0.82),
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparingOverlay extends StatelessWidget {
  const _PreparingOverlay({required this.messageKey});

  final String messageKey;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.36),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryPink,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    AppTexts.t(messageKey),
                    style: GoogleFonts.manrope(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoffeeCaptureBackground extends StatelessWidget {
  const _CoffeeCaptureBackground();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.1, -0.25),
            radius: 1.12,
            colors: [
              AppColors.cosmicGradientTop,
              AppColors.cosmicGradientMid,
              AppColors.background,
            ],
          ),
        ),
      ),
    );
  }
}
