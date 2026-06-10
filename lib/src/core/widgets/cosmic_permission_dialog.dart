import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_texts.dart';

class CosmicPermissionDialog extends StatelessWidget {
  const CosmicPermissionDialog({
    super.key,
    required this.onAllow,
    required this.onDecline,
  });

  final VoidCallback onAllow;
  final VoidCallback onDecline;

  static const _background = Color(0xFF140C1C);
  static const _border = Color(0x99B46CFF);
  static const _iconBackground = Color(0x332B1738);
  static const _iconColor = Color(0xFFFFD700);
  static const _titleColor = Colors.white;
  static const _bodyColor = Color(0xFFE3D9F0);
  static const _secondaryText = Color(0xFFCBBFDD);
  static const _primaryStart = Color(0xFFFF5ED6);
  static const _primaryEnd = Color(0xFF690DAB);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _background.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: _primaryEnd.withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _iconBackground,
                    border: Border.all(color: _border.withValues(alpha: 0.7)),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryStart.withValues(alpha: 0.18),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: _iconColor,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  AppTexts.t('notificationsPrimingTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _titleColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppTexts.t('notificationsPrimingBody'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _bodyColor,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onDecline,
                        style: TextButton.styleFrom(
                          foregroundColor: _secondaryText,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          AppTexts.t('notificationsPrimingNotNow'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [_primaryStart, _primaryEnd],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryStart.withValues(alpha: 0.3),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: onAllow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            AppTexts.t('notificationsPrimingAllow'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
