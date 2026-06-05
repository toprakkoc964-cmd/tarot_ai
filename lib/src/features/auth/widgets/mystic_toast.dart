import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';

enum MysticToastTone { error, success, warning, info }

class MysticToast {
  const MysticToast._();

  static final Map<String, DateTime> _lastShownAt = {};
  static OverlayEntry? _entry;
  static Timer? _dismissTimer;

  static void showError(
    BuildContext context,
    String message, {
    String? dedupeKey,
  }) {
    _show(context, message, MysticToastTone.error, dedupeKey: dedupeKey);
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? dedupeKey,
  }) {
    _show(context, message, MysticToastTone.success, dedupeKey: dedupeKey);
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? dedupeKey,
  }) {
    _show(context, message, MysticToastTone.warning, dedupeKey: dedupeKey);
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? dedupeKey,
  }) {
    _show(context, message, MysticToastTone.info, dedupeKey: dedupeKey);
  }

  static void _show(
    BuildContext context,
    String message,
    MysticToastTone tone, {
    String? dedupeKey,
    Duration minInterval = const Duration(seconds: 3),
  }) {
    if (message.trim().isEmpty) return;

    final key = dedupeKey ?? '${tone.name}:$message';
    final now = DateTime.now();
    final lastShown = _lastShownAt[key];
    if (lastShown != null && now.difference(lastShown) < minInterval) {
      return;
    }
    _lastShownAt[key] = now;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _dismissTimer?.cancel();
    _entry?.remove();

    _entry = OverlayEntry(
      builder: (context) => _MysticToastOverlay(message: message, tone: tone),
    );
    overlay.insert(_entry!);
    _dismissTimer = Timer(const Duration(seconds: 3), _hide);
  }

  static void _hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _MysticToastOverlay extends StatelessWidget {
  const _MysticToastOverlay({required this.message, required this.tone});

  final String message;
  final MysticToastTone tone;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final accent = switch (tone) {
      MysticToastTone.error => AppColors.primaryPink,
      MysticToastTone.success => AppColors.tertiaryGold,
      MysticToastTone.warning => AppColors.tertiaryGold,
      MysticToastTone.info => AppColors.secondaryLavender,
    };
    final icon = switch (tone) {
      MysticToastTone.error => Icons.error_outline_rounded,
      MysticToastTone.success => Icons.check_circle_outline_rounded,
      MysticToastTone.warning => Icons.report_problem_outlined,
      MysticToastTone.info => Icons.auto_awesome_rounded,
    };
    final titleKey = switch (tone) {
      MysticToastTone.error => 'toast.error_title',
      MysticToastTone.success => 'toast.success_title',
      MysticToastTone.warning => 'toast.warning_title',
      MysticToastTone.info => 'toast.info_title',
    };

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              mediaQuery.padding.top > 0 ? 8 : 16,
              16,
              0,
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, -12 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: accent, size: 22),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppTexts.t(titleKey),
                                  style: GoogleFonts.inter(
                                    color: accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  message,
                                  style: GoogleFonts.inter(
                                    color: AppColors.onSurface,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
