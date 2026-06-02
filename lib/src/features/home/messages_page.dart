import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/app_texts.dart';
import 'aris_session_service.dart';
import 'chat_page.dart';
import 'home_palette.dart';

const _kBg = HomePalette.background;
const _kPrimary = HomePalette.primary;
const _kSecondary = HomePalette.secondary;
const _kTertiary = HomePalette.tertiary;
const _kOnSurface = HomePalette.onSurface;
const _kGlassBg = HomePalette.glassBg;
const _kGlassBorder = HomePalette.glassBorder;

class MessagesPage extends StatelessWidget {
  const MessagesPage({
    super.key,
    required this.uid,
    required this.bottomInset,
  });

  final String uid;
  final double bottomInset;

  static double topBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top + 88;
  }

  @override
  Widget build(BuildContext context) {
    final service = ArisSessionService();
    return Stack(
      children: [
        const _MessagesBackground(),
        StreamBuilder<List<ArisSessionRecord>>(
          stream: service.watchSessions(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _kPrimary),
              );
            }

            if (snapshot.hasError) {
              return _MessagesError(
                message: AppTexts.t('messages.load_error'),
                bottomInset: bottomInset,
              );
            }

            final sessions = snapshot.data ?? const <ArisSessionRecord>[];
            if (sessions.isEmpty) {
              return _MessagesEmpty(bottomInset: bottomInset);
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                20,
                topBarHeight(context) + 16,
                20,
                bottomInset + 24,
              ),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _MessageSessionTile(
                  session: session,
                  locale: Localizations.localeOf(context).toString(),
                  onTap: () => _openSession(context, session),
                );
              },
            );
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _MessagesTopBar(),
        ),
      ],
    );
  }

  void _openSession(BuildContext context, ArisSessionRecord session) {
    Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (_) => KozmikBilgePage(
          uid: uid,
          resumeSessionId: session.sessionId,
          spreadCards: session.toDrawnCards(),
          spreadSessionId: session.sessionId,
          cardTitle: session.isSpread ? '' : session.cardName,
        ),
      ),
    );
  }
}

class _MessagesTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          color: _kBg.withValues(alpha: 0.82),
          padding: EdgeInsets.only(top: topPadding + 12, bottom: 14),
          child: Column(
            children: [
              Text(
                AppTexts.t('messages.title'),
                style: GoogleFonts.newsreader(
                  fontSize: 38,
                  fontStyle: FontStyle.italic,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppTexts.t('messages.subtitle'),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: _kSecondary.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageSessionTile extends StatelessWidget {
  const _MessageSessionTile({
    required this.session,
    required this.locale,
    required this.onTap,
  });

  final ArisSessionRecord session;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(session.updatedAt, locale);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: _kGlassBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kGlassBorder),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kPrimary.withValues(alpha: 0.14),
                  border: Border.all(
                    color: _kPrimary.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  session.isSpread
                      ? Icons.style_rounded
                      : Icons.auto_awesome_rounded,
                  color: _kTertiary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.titleLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _kOnSurface,
                            ),
                          ),
                        ),
                        if (dateLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            dateLabel,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              letterSpacing: 0.6,
                              color: _kSecondary.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        height: 1.4,
                        color: _kSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                    if (session.messageCount > 1) ...[
                      const SizedBox(height: 8),
                      Text(
                        AppTexts.t('messages.thread_count')
                            .replaceAll('{count}', '${session.messageCount}'),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          letterSpacing: 1,
                          color: _kPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: _kSecondary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime? value, String locale) {
    if (value == null) return '';
    return DateFormat('d MMM · HH:mm', locale).format(value);
  }
}

class _MessagesEmpty extends StatelessWidget {
  const _MessagesEmpty({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          32,
          MessagesPage.topBarHeight(context),
          32,
          bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 56,
              color: _kSecondary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              AppTexts.t('messages.empty_title'),
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                fontSize: 26,
                fontStyle: FontStyle.italic,
                color: _kOnSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppTexts.t('messages.empty_body'),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                height: 1.45,
                color: _kSecondary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesError extends StatelessWidget {
  const _MessagesError({
    required this.message,
    required this.bottomInset,
  });

  final String message;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          32,
          MessagesPage.topBarHeight(context),
          32,
          bottomInset,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: _kPrimary,
          ),
        ),
      ),
    );
  }
}

class _MessagesBackground extends StatelessWidget {
  const _MessagesBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _kBg,
              const Color(0xFF1A0B22),
              _kBg,
            ],
          ),
        ),
      ),
    );
  }
}
