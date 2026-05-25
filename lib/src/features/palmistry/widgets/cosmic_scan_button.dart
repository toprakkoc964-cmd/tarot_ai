import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class CosmicScanButton extends StatelessWidget {
  const CosmicScanButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.isLoading = false,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !isLoading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: active ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: active
                ? const [
                    AppColors.primaryPink,
                    AppColors.primaryNeonPink,
                  ]
                : [
                    AppColors.surfaceHigh.withValues(alpha: 0.95),
                    AppColors.surfaceHigh.withValues(alpha: 0.75),
                  ],
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primaryPink.withValues(alpha: 0.36),
                    blurRadius: 24,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: active ? onTap : null,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
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
                    Icon(
                      icon,
                      color: active
                          ? AppColors.onPrimary
                          : AppColors.secondaryLavender,
                      size: 20,
                    ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: active
                            ? AppColors.onPrimary
                            : AppColors.secondaryLavender,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.45,
                      ),
                    ),
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
