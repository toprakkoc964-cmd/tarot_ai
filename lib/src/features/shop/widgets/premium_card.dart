import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/shop_item_view_model.dart';

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.item,
    required this.onBuy,
    required this.isBusy,
    required this.isExpanded,
    required this.onToggle,
  });

  final ShopItemViewModel item;
  final VoidCallback? onBuy;
  final bool isBusy;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryPink.withValues(alpha: 0.16),
                AppColors.surfaceHigh.withValues(alpha: 0.92),
                AppColors.primaryNeonPink.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.primaryPink.withValues(alpha: 0.42),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryNeonPink.withValues(alpha: 0.18),
                blurRadius: 34,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.tertiaryGold.withValues(alpha: 0.14),
                      border: Border.all(
                        color: AppColors.tertiaryGold.withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.tertiaryGold,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.badge != null && item.badge!.isNotEmpty) ...[
                          _PremiumBadge(text: item.badge!),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          item.title,
                          style: GoogleFonts.newsreader(
                            color: AppColors.onSurface,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: GoogleFonts.manrope(
                            color: AppColors.secondaryLavender,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.secondaryLavender.withValues(
                        alpha: 0.82,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                item.priceText,
                style: GoogleFonts.spaceGrotesk(
                  color: item.isStoreProductLoaded
                      ? AppColors.tertiaryGold
                      : AppColors.secondaryLavender,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    for (final feature in item.features)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: AppColors.primaryPink,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                feature,
                                style: GoogleFonts.manrope(
                                  color: AppColors.onSurface.withValues(
                                    alpha: 0.86,
                                  ),
                                  fontSize: 13.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      AppTexts.t('premiumBonusCreditsInfo'),
                      style: GoogleFonts.manrope(
                        color: AppColors.tertiaryGold.withValues(alpha: 0.82),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: item.isPurchasable ? onBuy : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryNeonPink,
                          foregroundColor: AppColors.onPrimary,
                          disabledBackgroundColor: AppColors.secondaryLavender
                              .withValues(alpha: 0.10),
                          disabledForegroundColor: AppColors.secondaryLavender
                              .withValues(alpha: 0.52),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          isBusy
                              ? AppTexts.t('shopPurchasePending')
                              : item.isStoreProductLoaded
                              ? AppTexts.t('premiumCta')
                              : AppTexts.t('shopPriceUnavailable'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppTexts.t('shopSubscriptionRenewalInfo'),
                      style: GoogleFonts.manrope(
                        color: AppColors.secondaryLavender.withValues(
                          alpha: 0.78,
                        ),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tertiaryGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.tertiaryGold.withValues(alpha: 0.34),
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          color: AppColors.tertiaryGold,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
