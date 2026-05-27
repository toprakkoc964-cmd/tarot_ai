import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/ai_chat_context.dart';
import '../../home/chat_page.dart';
import '../models/coffee_reading_result.dart';
import '../services/coffee_temp_file_cleaner.dart';
import '../widgets/coffee_reading_card.dart';

class CoffeeResultScreen extends StatelessWidget {
  const CoffeeResultScreen({
    super.key,
    required this.uid,
    required this.imageFile,
    required this.result,
    required this.validationLabels,
  });

  final String uid;
  final File imageFile;
  final CoffeeReadingResult result;
  final List<String> validationLabels;

  @override
  Widget build(BuildContext context) {
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
                Text(
                  AppTexts.t('coffeeReadingReady'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.newsreader(
                    color: AppColors.primaryPink,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 26),
                CoffeeReadingCard(
                  title: AppTexts.t('coffeePast'),
                  body: result.past,
                  icon: Icons.history_rounded,
                ),
                const SizedBox(height: 14),
                CoffeeReadingCard(
                  title: AppTexts.t('coffeePresent'),
                  body: result.present,
                  icon: Icons.auto_awesome_rounded,
                ),
                const SizedBox(height: 14),
                CoffeeReadingCard(
                  title: AppTexts.t('coffeeFuture'),
                  body: result.future,
                  icon: Icons.trending_up_rounded,
                ),
                const SizedBox(height: 18),
                Text(
                  AppTexts.t('coffeeEntertainmentDisclaimer'),
                  style: GoogleFonts.manrope(
                    color: AppColors.secondaryLavender.withValues(alpha: 0.72),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () {
                    final contextData = AiChatContext.coffeeReadingMadamAris(
                      imageFiles: [imageFile],
                      validations: const {},
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => KozmikBilgePage(
                          uid: uid,
                          chatContext: contextData,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: Text(AppTexts.t('coffeeChatWithMadamAris')),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    foregroundColor: AppColors.onPrimary,
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

class CoffeeResultCleanupScope extends StatefulWidget {
  const CoffeeResultCleanupScope({
    super.key,
    required this.imageFile,
    required this.child,
  });

  final File imageFile;
  final Widget child;

  @override
  State<CoffeeResultCleanupScope> createState() =>
      _CoffeeResultCleanupScopeState();
}

class _CoffeeResultCleanupScopeState extends State<CoffeeResultCleanupScope> {
  @override
  void dispose() {
    GetIt.I<CoffeeTempFileCleaner>().cleanup([widget.imageFile]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
