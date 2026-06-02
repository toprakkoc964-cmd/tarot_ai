import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
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

class MessagesPage extends StatefulWidget {
  const MessagesPage({
    super.key,
    required this.uid,
    required this.bottomInset,
    this.showBackButton = false,
  });

  final String uid;
  final double bottomInset;
  final bool showBackButton;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _service = ArisSessionService();
  StreamSubscription<List<ArisSessionRecord>>? _subscription;
  List<ArisSessionRecord> _sessions = const [];
  bool _loading = true;
  String? _errorMessage;
  bool _usingServerFallback = false;

  @override
  void initState() {
    super.initState();
    _startListening();
    unawaited(_loadFromFirestoreIfNeeded());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _applySessions(List<ArisSessionRecord> sessions) {
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _loading = false;
      _errorMessage = null;
    });
  }

  void _mergeAndApply({
    required List<ArisSessionRecord> incoming,
    bool fromServer = false,
  }) {
    if (!mounted) return;
    final merged = ArisSessionService.mergeSessions(_sessions, incoming);
    setState(() {
      _sessions = merged;
      _loading = false;
      _errorMessage = null;
      if (fromServer) _usingServerFallback = true;
    });
  }

  void _startListening() {
    unawaited(_subscription?.cancel());
    setState(() {
      _loading = _sessions.isEmpty;
      _errorMessage = null;
    });

    _subscription = _service.watchSessions(widget.uid).listen(
      (sessions) {
        if (!mounted) return;
        if (_usingServerFallback && _sessions.isNotEmpty) {
          _mergeAndApply(incoming: sessions);
        } else {
          _applySessions(sessions);
          _usingServerFallback = false;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          debugPrint('aris_sessions stream error: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        unawaited(_loadFromFirestore(showLoading: !_usingServerFallback));
      },
    );
  }

  Future<void> _loadFromFirestoreIfNeeded() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted || !_loading || _sessions.isNotEmpty) return;
    await _loadFromFirestore(showLoading: false);
  }

  Future<void> _loadFromFirestore({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = _sessions.isEmpty;
        _errorMessage = null;
      });
    }

    try {
      final sessions = await _service.fetchSessionsFromFirestore(widget.uid);
      if (!mounted) return;
      if (_sessions.isEmpty) {
        _applySessions(sessions);
      } else {
        _mergeAndApply(incoming: sessions);
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('aris_sessions Firestore load failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      if (_sessions.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = AppTexts.t('messages.load_error');
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await _loadFromFirestore(showLoading: _sessions.isEmpty);
    try {
      final sessions = await _service.fetchSessions(widget.uid);
      if (!mounted) return;
      _mergeAndApply(incoming: sessions, fromServer: true);
    } catch (_) {}
    if (!mounted) return;
    if (!_usingServerFallback) {
      _startListening();
    }
  }

  void _openSession(ArisSessionRecord session) {
    Navigator.of(context)
        .push(
      MaterialPageRoute<String>(
        builder: (_) => KozmikBilgePage(
          uid: widget.uid,
          resumeSessionId: session.sessionId,
          spreadCards: session.toDrawnCards(),
          spreadSessionId: session.sessionId,
          cardTitle: session.isSpread ? '' : session.cardName,
        ),
      ),
    )
        .then((_) {
      if (mounted) unawaited(_refreshAll());
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kBg,
      child: Stack(
        children: [
          const _MessagesBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MessagesTopBar(showBackButton: widget.showBackButton),
                Expanded(child: _buildBody(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _sessions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _kPrimary),
      );
    }

    if (_errorMessage != null && _sessions.isEmpty) {
      return _MessagesError(
        message: _errorMessage!,
        onRetry: _refreshAll,
      );
    }

    if (_sessions.isEmpty) {
      return RefreshIndicator(
        color: _kPrimary,
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
            const _MessagesEmpty(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: _refreshAll,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 8, 20, widget.bottomInset + 24),
        itemCount: _sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final session = _sessions[index];
          return _MessageSessionTile(
            session: session,
            locale: Localizations.localeOf(context).toString(),
            onTap: () => _openSession(session),
          );
        },
      ),
    );
  }
}

class _MessagesTopBar extends StatelessWidget {
  const _MessagesTopBar({this.showBackButton = false});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          color: _kBg.withValues(alpha: 0.82),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              if (showBackButton)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _kSecondary,
                      size: 20,
                    ),
                  ),
                ),
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
  const _MessagesEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: _kPrimary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  side: BorderSide(color: _kPrimary.withValues(alpha: 0.4)),
                ),
                child: Text(AppTexts.t('messages.retry')),
              ),
            ],
          ],
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
