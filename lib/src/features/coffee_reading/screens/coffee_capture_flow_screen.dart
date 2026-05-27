import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/ai_chat_context.dart';
import '../../home/chat_page.dart';
import '../models/coffee_image_pipeline_result.dart';
import '../models/coffee_photo_step.dart';
import '../services/coffee_image_pipeline_service.dart';
import '../services/coffee_temp_file_cleaner.dart';
import '../widgets/coffee_capture_card.dart';
import '../widgets/coffee_capture_progress.dart';
import '../widgets/coffee_source_bottom_sheet.dart';
import 'coffee_loading_screen.dart';

class CoffeeCaptureFlowScreen extends StatefulWidget {
  const CoffeeCaptureFlowScreen({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  State<CoffeeCaptureFlowScreen> createState() =>
      _CoffeeCaptureFlowScreenState();
}

class _CoffeeCaptureFlowScreenState extends State<CoffeeCaptureFlowScreen> {
  final Map<CoffeePhotoStep, CoffeeImagePipelineResult> _completedSteps = {};

  CoffeePhotoStep _activeStep = CoffeePhotoStep.cupInside;
  bool _isProcessing = false;
  bool _isNavigating = false;
  bool _ownershipTransferred = false;

  CoffeeImagePipelineService get _pipeline =>
      GetIt.I<CoffeeImagePipelineService>();
  CoffeeTempFileCleaner get _cleaner => GetIt.I<CoffeeTempFileCleaner>();

  @override
  void dispose() {
    if (!_ownershipTransferred) {
      unawaited(
        _cleaner.cleanup(
          _completedSteps.values.expand((result) => result.tempFiles),
        ),
      );
    }
    super.dispose();
  }

  Future<void> _chooseSourceForStep(CoffeePhotoStep step) async {
    if (_isProcessing || _isNavigating) return;
    setState(() => _activeStep = step);

    final source = await CoffeeSourceBottomSheet.show(context);
    if (source == null || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _pipeline.processImage(source, step);
      if (result == null || !mounted) return;

      final previous = _completedSteps[step];
      if (previous != null) {
        await _cleaner.cleanup(previous.tempFiles);
      }

      final imagePath = result.compressedImage.path;
      await _cleaner.cleanup(
        result.tempFiles.where((file) => file.path != imagePath),
      );

      if (!mounted) return;
      setState(() {
        _completedSteps[step] = result;
        _activeStep = _nextIncompleteStep() ?? step;
      });

      if (_completedSteps.length == CoffeePhotoStep.values.length) {
        await _openMadamAris();
      }
    } on CoffeePipelineException catch (error) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      if (error.messageKey == 'coffeeInvalidImage') {
        await _showInvalidImageDialog(step);
      } else {
        _showSnack(AppTexts.t(error.messageKey));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnack(AppTexts.t('coffeeValidationFailed'));
      }
    } finally {
      if (mounted && !_isNavigating) {
        setState(() => _isProcessing = false);
      }
    }
  }

  CoffeePhotoStep? _nextIncompleteStep() {
    for (final step in CoffeePhotoStep.values) {
      if (!_completedSteps.containsKey(step)) return step;
    }
    return null;
  }

  Future<void> _showInvalidImageDialog(CoffeePhotoStep step) async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          title: Text(
            AppTexts.t('coffeeValidationFailed'),
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            AppTexts.t('coffeeInvalidImageDetailed'),
            style: GoogleFonts.manrope(
              color: AppColors.secondaryLavender,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppTexts.t('common.close')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(AppTexts.t('coffeeRetakePhoto')),
            ),
          ],
        );
      },
    );

    if (retry == true && mounted) {
      await _chooseSourceForStep(step);
    }
  }

  Future<void> _openMadamAris() async {
    if (_isNavigating ||
        _completedSteps.length != CoffeePhotoStep.values.length) {
      return;
    }

    // TODO Sprint 3:
    // Before Gemini analysis, call backend CreditService.
    // Deduct CoffeeFortuneAnalysis cost with Firestore transaction / backend API.
    // If analysis fails, backend should refund credits.
    // Never store API keys in Flutter.

    final imageFiles = CoffeePhotoStep.values
        .map((step) => _completedSteps[step]!.compressedImage)
        .toList(growable: false);
    final validations = {
      for (final entry in _completedSteps.entries)
        entry.key: entry.value.validationResult,
    };
    final contextData = AiChatContext.coffeeReadingMadamAris(
      imageFiles: imageFiles,
      validations: validations,
    );

    setState(() {
      _isNavigating = true;
      _ownershipTransferred = true;
    });

    if (!mounted) return;
    await Navigator.of(context).pushReplacement<void, void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: _CoffeeLoadingBridge(
              uid: widget.uid,
              chatContext: contextData,
            ),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
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
      canPop: !_isProcessing && !_isNavigating,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const _CoffeeCaptureBackground(),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _isProcessing || _isNavigating
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
                      color:
                          AppColors.secondaryLavender.withValues(alpha: 0.84),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 26),
                  CoffeeCaptureProgress(
                    activeStep: _activeStep,
                    completedSteps: _completedSteps,
                  ),
                  const SizedBox(height: 24),
                  CoffeeCaptureCard(
                    step: _activeStep,
                    result: _completedSteps[_activeStep],
                    isProcessing: _isProcessing,
                    onAddPhoto: () => _chooseSourceForStep(_activeStep),
                  ),
                  const SizedBox(height: 18),
                  _CompletedSummary(completedCount: _completedSteps.length),
                ],
              ),
            ),
            if (_isProcessing) const _PreparingOverlay(),
          ],
        ),
      ),
    );
  }
}

class _CoffeeLoadingBridge extends StatefulWidget {
  const _CoffeeLoadingBridge({
    required this.uid,
    required this.chatContext,
  });

  final String uid;
  final AiChatContext chatContext;

  @override
  State<_CoffeeLoadingBridge> createState() => _CoffeeLoadingBridgeState();
}

class _CoffeeLoadingBridgeState extends State<_CoffeeLoadingBridge> {
  @override
  void initState() {
    super.initState();
    _continueToChat();
  }

  Future<void> _continueToChat() async {
    await Future<void>.delayed(const Duration(milliseconds: 1350));
    if (!mounted) return;
    await Navigator.of(context).pushReplacement<void, void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: KozmikBilgePage(
              uid: widget.uid,
              chatContext: widget.chatContext,
            ),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
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
  }

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: CoffeeLoadingScreen(),
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
                  : AppTexts.t('coffeeProgressHint').replaceFirst(
                      '{count}',
                      completedCount.toString(),
                    ),
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
  const _PreparingOverlay();

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
                    AppTexts.t('coffeePreparingPhoto'),
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
