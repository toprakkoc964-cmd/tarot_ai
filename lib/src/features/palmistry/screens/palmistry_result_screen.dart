import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/ai_chat_context.dart';
import '../../home/chat_page.dart';
import '../../shop/screens/credit_purchase_sheet.dart';
import '../models/palmistry_result.dart';
import '../widgets/cosmic_scan_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/palm_reading_card.dart';
import 'palm_scanner_screen.dart';

class PalmistryResultScreen extends StatelessWidget {
  const PalmistryResultScreen({super.key, required this.result});

  final PalmistryResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _ResultBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.primaryPink,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Hero(
                  tag: PalmScannerScreen.heroTag,
                  child: Material(
                    color: Colors.transparent,
                    child: GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 28,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 94,
                            height: 94,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceHigh.withValues(
                                alpha: 0.72,
                              ),
                              border: Border.all(color: AppColors.glassBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.tertiaryGold.withValues(
                                    alpha: 0.28,
                                  ),
                                  blurRadius: 32,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.front_hand_rounded,
                              color: AppColors.tertiaryGold,
                              size: 46,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppTexts.t('palmResultTitle'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.newsreader(
                              color: AppColors.onSurface,
                              fontSize: 34,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppTexts.t('palmResultDescription'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: AppColors.secondaryLavender.withValues(
                                alpha: 0.9,
                              ),
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                PalmReadingCard(
                  title: AppTexts.t('mindLineTitle'),
                  body: result.reading.mindLine,
                  icon: Icons.psychology_alt_rounded,
                ),
                const SizedBox(height: 14),
                PalmReadingCard(
                  title: AppTexts.t('heartLineTitle'),
                  body: result.reading.heartLine,
                  icon: Icons.favorite_rounded,
                ),
                const SizedBox(height: 14),
                PalmReadingCard(
                  title: AppTexts.t('lifeEnergyTitle'),
                  body: result.reading.lifeEnergy,
                  icon: Icons.bolt_rounded,
                ),
                const SizedBox(height: 18),
                Text(
                  AppTexts.t('entertainmentDisclaimer'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppColors.secondaryLavender.withValues(alpha: 0.7),
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                if ((result.sessionId ?? '').trim().isNotEmpty) ...[
                  CosmicScanButton(
                    text: AppTexts.t('palmChatWithMadamAris'),
                    icon: Icons.chat_bubble_rounded,
                    onTap: () => _openMadamArisChat(context),
                  ),
                  const SizedBox(height: 12),
                ],
                CosmicScanButton(
                  text: AppTexts.t('scanAgain'),
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const PalmScannerScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMadamArisChat(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final sessionId = result.sessionId?.trim() ?? '';
    if (uid.isEmpty || sessionId.isEmpty) return;

    final chatResult = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => KozmikBilgePage(
          uid: uid,
          resumeSessionId: sessionId,
          chatContext: AiChatContext.palmReadingMadamAris(sessionId: sessionId),
        ),
      ),
    );
    if (!context.mounted || chatResult != 'credits') return;
    await showCreditPurchaseSheet(context, uid: uid);
  }
}

class _ResultBackground extends StatelessWidget {
  const _ResultBackground();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.cosmicGradientMid,
              AppColors.background,
            ],
          ),
        ),
      ),
    );
  }
}
