import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';

class CosmicBenefitsRow extends StatefulWidget {
  const CosmicBenefitsRow({super.key});

  @override
  State<CosmicBenefitsRow> createState() => _CosmicBenefitsRowState();
}

class _CosmicBenefitsRowState extends State<CosmicBenefitsRow>
    with SingleTickerProviderStateMixin {
  static const int _virtualItemCount = 9000;
  static const int _virtualStartIndex = 4500;
  static const double _gap = 14;
  static const double _cardSize = 180;
  static const double _pixelsPerSecond = 30;

  late final ScrollController _controller;
  late final AnimationController _ticker;
  Duration? _lastElapsed;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: _virtualStartIndex * (_cardSize + _gap),
    );
    _ticker = AnimationController.unbounded(vsync: this)
      ..addListener(_scrollOnTick)
      ..repeat(min: 0, max: 1, period: const Duration(days: 1));
  }

  @override
  void dispose() {
    _ticker
      ..removeListener(_scrollOnTick)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _scrollOnTick() {
    if (!mounted || !_controller.hasClients) return;

    final elapsed = _ticker.lastElapsedDuration;
    if (elapsed == null) return;
    final previous = _lastElapsed;
    _lastElapsed = elapsed;
    if (previous == null) return;

    final position = _controller.position;
    if (!position.hasContentDimensions) return;

    final deltaSeconds = (elapsed - previous).inMicroseconds / 1000000;
    final nextOffset = position.pixels + deltaSeconds * _pixelsPerSecond;
    if (nextOffset >= position.maxScrollExtent - 800) {
      _controller.jumpTo(position.minScrollExtent + 800);
      return;
    }

    _controller.jumpTo(nextOffset);
  }

  @override
  Widget build(BuildContext context) {
    final benefits = [
      _BenefitData(
        icon: Icons.headphones_rounded,
        title: AppTexts.t('shopBenefit1Title'),
        description: AppTexts.t('shopBenefit1Desc'),
      ),
      _BenefitData(
        icon: Icons.tune_rounded,
        title: AppTexts.t('shopBenefit2Title'),
        description: AppTexts.t('shopBenefit2Desc'),
      ),
      _BenefitData(
        icon: Icons.auto_stories_rounded,
        title: AppTexts.t('shopBenefit3Title'),
        description: AppTexts.t('shopBenefit3Desc'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppTexts.t('shopBenefitsSectionTitle'),
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 192,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ListView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                clipBehavior: Clip.none,
                itemCount: _virtualItemCount,
                itemBuilder: (context, index) {
                  final item = benefits[index % benefits.length];
                  return Padding(
                    padding: const EdgeInsets.only(right: _gap),
                    child: _BenefitCard(data: item),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.data});

  final _BenefitData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _CosmicBenefitsRowState._cardSize,
      height: _CosmicBenefitsRowState._cardSize,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryPink.withValues(alpha: 0.18),
            AppColors.surfaceHigh.withValues(alpha: 0.86),
            AppColors.primaryNeonPink.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryPink.withValues(alpha: 0.42),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNeonPink.withValues(alpha: 0.28),
            blurRadius: 30,
            spreadRadius: -6,
          ),
          BoxShadow(
            color: AppColors.tertiaryGold.withValues(alpha: 0.10),
            blurRadius: 22,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryPink.withValues(alpha: 0.20),
              border: Border.all(
                color: AppColors.primaryPink.withValues(alpha: 0.44),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNeonPink.withValues(alpha: 0.22),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Icon(data.icon, color: AppColors.primaryPink, size: 23),
          ),
          const SizedBox(height: 18),
          Text(
            data.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.onSurface,
              fontSize: 15.5,
              height: 1.12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: AppColors.secondaryLavender.withValues(alpha: 0.80),
              fontSize: 12.5,
              height: 1.22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitData {
  const _BenefitData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
