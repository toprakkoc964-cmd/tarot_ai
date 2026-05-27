import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/ai_chat_context.dart';
import '../../home/chat_page.dart';
import '../models/coffee_image_pipeline_result.dart';
import '../services/coffee_temp_file_cleaner.dart';

class CoffeePhotoPreviewScreen extends StatefulWidget {
  const CoffeePhotoPreviewScreen({
    super.key,
    required this.uid,
    required this.pipelineResult,
  });

  final String uid;
  final CoffeeImagePipelineResult pipelineResult;

  @override
  State<CoffeePhotoPreviewScreen> createState() =>
      _CoffeePhotoPreviewScreenState();
}

class _CoffeePhotoPreviewScreenState extends State<CoffeePhotoPreviewScreen> {
  bool _isNavigating = false;
  bool _imageOwnershipTransferred = false;

  CoffeeTempFileCleaner get _cleaner => GetIt.I<CoffeeTempFileCleaner>();

  @override
  void dispose() {
    if (!_imageOwnershipTransferred) {
      _cleaner.cleanup(widget.pipelineResult.tempFiles);
    }
    super.dispose();
  }

  Future<void> _openMadamAris() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    // TODO Sprint 3:
    // Before Gemini analysis, call backend CreditService.
    // Deduct CoffeeFortuneAnalysis cost with Firestore transaction / backend API.
    // If analysis fails, backend should refund credits.
    // Never store API keys in Flutter.

    final imageFile = widget.pipelineResult.compressedImage;
    final filesNoLongerNeeded = widget.pipelineResult.tempFiles.where(
      (file) => file.path != imageFile.path,
    );
    await _cleaner.cleanup(filesNoLongerNeeded);
    _imageOwnershipTransferred = true;

    if (!mounted) return;
    final contextData = AiChatContext.coffeeReadingMadamAris(
      imageFiles: [imageFile],
      validations: {
        widget.pipelineResult.step: widget.pipelineResult.validationResult,
      },
    );
    await Navigator.of(context).pushReplacement<String, String>(
      PageRouteBuilder<String>(
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: KozmikBilgePage(
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
              scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _retake() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    await _cleaner.cleanup(widget.pipelineResult.tempFiles);
    if (mounted) Navigator.of(context).pop('retake');
  }

  @override
  Widget build(BuildContext context) {
    final validation = widget.pipelineResult.validationResult;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _CoffeePreviewBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed:
                          _isNavigating ? null : () => Navigator.pop(context),
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
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 24),
                _ImageCard(imageFile: widget.pipelineResult.compressedImage),
                const SizedBox(height: 24),
                _GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTexts.t('coffeePreviewTitle'),
                        style: GoogleFonts.newsreader(
                          color: AppColors.onSurface,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            validation.hasWarning
                                ? Icons.auto_awesome_rounded
                                : Icons.check_circle_rounded,
                            color: validation.hasWarning
                                ? AppColors.tertiaryGold
                                : AppColors.primaryPink,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              validation.hasWarning
                                  ? AppTexts.t('coffeeWeakImageWarning')
                                  : AppTexts.t('coffeeCupDetected'),
                              style: GoogleFonts.manrope(
                                color: AppColors.secondaryLavender,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        AppTexts.t('coffeePhotoPrivacyNote'),
                        style: GoogleFonts.manrope(
                          color: AppColors.secondaryLavender.withValues(
                            alpha: 0.72,
                          ),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _PrimaryButton(
                  text: AppTexts.t('coffeeStartMadamAris'),
                  icon: Icons.auto_awesome_rounded,
                  isLoading: _isNavigating,
                  onTap: _openMadamAris,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _isNavigating ? null : _retake,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(AppTexts.t('coffeeRetakePhoto')),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondaryLavender,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.imageFile});

  final File imageFile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPink.withValues(alpha: 0.24),
              blurRadius: 42,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Image.file(
            imageFile,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryPink,
            AppColors.primaryNeonPink,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withValues(alpha: 0.32),
            blurRadius: 24,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                else
                  Icon(icon, color: AppColors.onPrimary, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
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

class _CoffeePreviewBackground extends StatelessWidget {
  const _CoffeePreviewBackground();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.1, -0.28),
            radius: 1.05,
            colors: [
              AppColors.cosmicGradientTop,
              AppColors.background,
            ],
          ),
        ),
      ),
    );
  }
}
