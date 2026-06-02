import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/tarot_functions_client.dart';
import '../../../core/theme/app_colors.dart';
import '../models/coffee_reading_result.dart';
import '../widgets/coffee_reading_card.dart';

class CoffeeResultScreen extends StatefulWidget {
  const CoffeeResultScreen({
    super.key,
    required this.uid,
    required this.result,
  });

  final String uid;
  final CoffeeReadingResult result;

  @override
  State<CoffeeResultScreen> createState() => _CoffeeResultScreenState();
}

class _CoffeeResultScreenState extends State<CoffeeResultScreen> {
  bool _isDeletingPhotos = false;
  bool _photosDeleted = false;

  Future<void> _deletePhotos() async {
    if (_isDeletingPhotos || _photosDeleted) return;
    setState(() => _isDeletingPhotos = true);
    try {
      await GetIt.I<TarotFunctionsClient>().deleteCoffeeReadingPhotos(
        readingId: widget.result.readingId,
      );
      if (!mounted) return;
      setState(() => _photosDeleted = true);
      _showSnack(AppTexts.t('coffeeDeletePhotosSuccess'));
    } catch (_) {
      if (!mounted) return;
      _showSnack(AppTexts.t('coffeeDeletePhotosFailed'));
    } finally {
      if (mounted) setState(() => _isDeletingPhotos = false);
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
    final reading = widget.result.reading;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.15, -0.2),
                  radius: 1.05,
                  colors: [
                    AppColors.cosmicGradientTop,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.primaryPink,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        AppTexts.t('coffeeReadingReady'),
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
                const SizedBox(height: 20),
                CoffeeReadingCard(
                  title: AppTexts.t('coffeeReadingGeneralEnergy'),
                  body: reading.generalEnergy,
                  icon: Icons.blur_on_rounded,
                ),
                const SizedBox(height: 14),
                CoffeeReadingCard(
                  title: AppTexts.t('coffeeReadingSymbols'),
                  body: reading.symbols,
                  icon: Icons.auto_awesome_rounded,
                ),
                const SizedBox(height: 14),
                CoffeeReadingCard(
                  title: AppTexts.t('coffeeReadingSaucerSigns'),
                  body: reading.saucerSigns,
                  icon: Icons.radio_button_unchecked_rounded,
                ),
                const SizedBox(height: 14),
                CoffeeReadingCard(
                  title: AppTexts.t('coffeeReadingOuterCupMessage'),
                  body: reading.outerCupMessage,
                  icon: Icons.coffee_rounded,
                ),
                const SizedBox(height: 14),
                CoffeeReadingCard(
                  title: AppTexts.t('coffeeReadingPastTrace'),
                  body: reading.pastTrace,
                  icon: Icons.history_rounded,
                ),
                const SizedBox(height: 14),
                CoffeeReadingCard(
                  title: AppTexts.t('coffeeReadingPresentMood'),
                  body: reading.presentMood,
                  icon: Icons.wb_twilight_rounded,
                ),
                const SizedBox(height: 14),
                CoffeeReadingCard(
                  title: AppTexts.t('coffeeReadingNearFutureMessage'),
                  body: reading.nearFutureMessage,
                  icon: Icons.trending_up_rounded,
                ),
                const SizedBox(height: 14),
                CoffeeReadingCard(
                  title: AppTexts.t('coffeeReadingAdvice'),
                  body: reading.advice,
                  icon: Icons.favorite_rounded,
                ),
                const SizedBox(height: 18),
                Text(
                  reading.disclaimer.isNotEmpty
                      ? reading.disclaimer
                      : AppTexts.t('coffeeReadingDisclaimer'),
                  style: GoogleFonts.manrope(
                    color: AppColors.secondaryLavender.withValues(alpha: 0.72),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppTexts.t('coffeePhotosRetentionInfo'),
                  style: GoogleFonts.manrope(
                    color: AppColors.secondaryLavender.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _photosDeleted || _isDeletingPhotos
                      ? null
                      : _deletePhotos,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPink,
                    side: BorderSide(color: AppColors.glassBorder),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: _isDeletingPhotos
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryPink,
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    _photosDeleted
                        ? AppTexts.t('coffeeDeletePhotosSuccess')
                        : AppTexts.t('coffeeDeletePhotos'),
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
