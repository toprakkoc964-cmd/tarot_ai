import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';

class CoffeeSourceBottomSheet extends StatelessWidget {
  const CoffeeSourceBottomSheet({super.key});

  static Future<ImageSource?> show(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      isScrollControlled: true,
      builder: (_) => const CoffeeSourceBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              decoration: BoxDecoration(
                color: AppColors.glassBg,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.glassBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryNeonPink.withValues(alpha: 0.18),
                    blurRadius: 36,
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLavender.withValues(
                          alpha: 0.32,
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    AppTexts.t('coffeeTitle'),
                    style: GoogleFonts.newsreader(
                      color: AppColors.onSurface,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppTexts.t('coffeeDescription'),
                    style: GoogleFonts.manrope(
                      color: AppColors.secondaryLavender.withValues(
                        alpha: 0.88,
                      ),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SourceButton(
                    icon: Icons.photo_camera_rounded,
                    text: AppTexts.t('coffeeOpenCamera'),
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  _SourceButton(
                    icon: Icons.photo_library_rounded,
                    text: AppTexts.t('coffeeChooseGallery'),
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceHigh.withValues(alpha: 0.78),
            AppColors.primaryPink.withValues(alpha: 0.14),
          ],
        ),
        border: Border.all(
          color: AppColors.primaryPink.withValues(alpha: 0.28),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryPink, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.05,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.secondaryLavender,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
