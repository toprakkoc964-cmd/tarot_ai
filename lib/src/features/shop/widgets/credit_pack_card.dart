import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/shop_item_view_model.dart';

class CreditPackCard extends StatelessWidget {
  const CreditPackCard({
    super.key,
    required this.item,
    required this.onBuy,
    required this.isBusy,
  });

  final ShopItemViewModel item;
  final VoidCallback? onBuy;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: item.isHighlighted
            ? AppColors.surfaceHigh.withValues(alpha: 0.84)
            : AppColors.glassBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: item.isHighlighted
              ? AppColors.primaryPink.withValues(alpha: 0.42)
              : AppColors.glassBorder,
          width: item.isHighlighted ? 1.6 : 1,
        ),
        boxShadow: item.isHighlighted
            ? [
                BoxShadow(
                  color: AppColors.primaryNeonPink.withValues(alpha: 0.16),
                  blurRadius: 26,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tertiaryGold.withValues(alpha: 0.16),
                ),
                child: const Icon(
                  Icons.generating_tokens_rounded,
                  color: AppColors.tertiaryGold,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.badge != null && item.badge!.isNotEmpty) ...[
                      _Badge(text: item.badge!),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      item.title,
                      style: GoogleFonts.newsreader(
                        color: AppColors.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.manrope(
                        color: AppColors.secondaryLavender,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item.priceText,
            style: GoogleFonts.spaceGrotesk(
              color: item.isStoreProductLoaded
                  ? AppColors.tertiaryGold
                  : AppColors.secondaryLavender,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          for (final feature in item.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.primaryPink,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: GoogleFonts.manrope(
                        color: AppColors.onSurface.withValues(alpha: 0.76),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: item.isPurchasable ? onBuy : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryPink,
                foregroundColor: AppColors.onPrimary,
                disabledBackgroundColor:
                    AppColors.secondaryLavender.withValues(alpha: 0.10),
                disabledForegroundColor:
                    AppColors.secondaryLavender.withValues(alpha: 0.52),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                isBusy
                    ? AppTexts.t('shopPurchasePending')
                    : item.isStoreProductLoaded
                        ? AppTexts.t('home.credit.cta.recharge')
                        : AppTexts.t('shopPriceUnavailable'),
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryPink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primaryPink.withValues(alpha: 0.32),
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          color: AppColors.primaryPink,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
