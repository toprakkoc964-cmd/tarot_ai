import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ads/app_ad_reward_service.dart';
import '../../core/ads/app_ad_service.dart';
import '../../core/app_texts.dart';
import '../../core/widgets/inline_ad_banner.dart';
import 'ai_chat_context.dart';
import 'aris_session_service.dart';
import '../auth/widgets/mystic_toast.dart';
import '../shop/screens/credit_purchase_sheet.dart';
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
  ArisSessionCategory _selectedCategory = ArisSessionCategory.tarot;
  bool _loading = true;
  String? _errorMessage;
  bool _usingServerFallback = false;
  DateTime? _archiveUnlockUntil;
  bool _unlockInFlight = false;

  String get _cacheKey => 'aris_archive_cache_${widget.uid}';
  bool get _archiveUnlocked =>
      AppAdRewardService.instance.isArchiveUnlocked(_archiveUnlockUntil);

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _loadArchiveUnlockState();
    await _loadCachedSessions();
    if (!mounted) return;
    _startListening();
    unawaited(_refreshAll());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _loadCachedSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final sessions = <ArisSessionRecord>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final sessionId = (map['sessionId'] as String?)?.trim() ?? '';
        if (sessionId.isEmpty) continue;
        sessions.add(
          ArisSessionRecord.fromMap(sessionId: sessionId, data: map),
        );
      }

      if (!mounted || sessions.isEmpty) return;
      setState(() {
        _sessions = ArisSessionService.mapAndSortSessions(sessions);
        _loading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('aris archive cache read failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> _loadArchiveUnlockState() async {
    final unlockUntil = await AppAdRewardService.instance
        .loadArchiveUnlockUntil(widget.uid);
    if (!mounted) return;
    setState(() => _archiveUnlockUntil = unlockUntil);
  }

  Future<void> _persistSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(
        _sessions.map((session) => session.toMap()).toList(),
      );
      await prefs.setString(_cacheKey, payload);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('aris archive cache write failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  void _applySessions(List<ArisSessionRecord> sessions) {
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _loading = false;
      _errorMessage = null;
    });
    unawaited(_persistSessions());
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
    unawaited(_persistSessions());
  }

  void _startListening() {
    unawaited(_subscription?.cancel());
    setState(() {
      _loading = _sessions.isEmpty;
      _errorMessage = null;
    });

    _subscription = _service
        .watchSessions(widget.uid)
        .listen(
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

  Future<void> _openSession(ArisSessionRecord session) async {
    final isFreelyAccessible =
        _archiveUnlocked ||
        AppAdRewardService.instance.isSameLocalDay(session.updatedAt);
    if (!isFreelyAccessible) {
      unawaited(_watchArchiveUnlockAd());
      return;
    }

    final isTarot = session.category == ArisSessionCategory.tarot;
    final chatContext = switch (session.category) {
      ArisSessionCategory.palm => AiChatContext.palmReadingMadamAris(
        sessionId: session.sessionId,
      ),
      ArisSessionCategory.numerology =>
        AiChatContext.numerologyReadingMadamAris(sessionId: session.sessionId),
      ArisSessionCategory.coffee => AiChatContext(
        persona: AiPersona.madamAris,
        mode: AiChatMode.coffeeReading,
        title: AppTexts.t('coffeeMadamArisTitle'),
        metadata: {'source': 'coffee_reading', 'sessionId': session.sessionId},
      ),
      ArisSessionCategory.tarot => null,
    };
    await AppAdService.instance.maybeShowPageTransitionInterstitial();
    if (!mounted) return;

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => KozmikBilgePage(
          uid: widget.uid,
          resumeSessionId: session.sessionId,
          spreadCards: isTarot ? session.toDrawnCards() : const [],
          spreadSessionId: isTarot ? session.sessionId : null,
          cardTitle: isTarot && !session.isSpread ? session.cardName : '',
          chatContext: chatContext,
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'credits') {
      unawaited(showCreditPurchaseSheet(context, uid: widget.uid));
    }
    unawaited(_refreshAll());
  }

  Future<void> _watchArchiveUnlockAd() async {
    if (_unlockInFlight) return;
    setState(() => _unlockInFlight = true);

    try {
      final adResult = await AppAdService.instance.showRewarded(
        AppRewardedPlacement.archiveUnlock,
        userId: widget.uid,
      );
      if (!mounted) return;

      if (adResult.unavailable) {
        MysticToast.showInfo(
          context,
          AppTexts.t('ads.common.not_ready'),
          dedupeKey: 'archive-ad-not-ready',
        );
        return;
      }

      if (!adResult.earned) return;

      final unlockUntil = await AppAdRewardService.instance
          .unlockArchiveFor24Hours(widget.uid);
      if (!mounted) return;
      setState(() => _archiveUnlockUntil = unlockUntil);
      MysticToast.showSuccess(
        context,
        AppTexts.t('ads.archive.unlock_success'),
        dedupeKey: 'archive-ad-success-${unlockUntil.millisecondsSinceEpoch}',
      );
    } finally {
      if (mounted) {
        setState(() => _unlockInFlight = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
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
                  _ArchiveCategoryTabs(
                    selectedCategory: _selectedCategory,
                    onSelected: (category) {
                      if (_selectedCategory == category) return;
                      setState(() => _selectedCategory = category);
                    },
                  ),
                  Expanded(child: _buildBody(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _sessions.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    if (_errorMessage != null && _sessions.isEmpty) {
      return _MessagesError(message: _errorMessage!, onRetry: _refreshAll);
    }

    if (_sessions.isEmpty) {
      return RefreshIndicator(
        color: _kPrimary,
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 8, 20, widget.bottomInset + 24),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.16),
            _MessagesEmpty(category: _selectedCategory),
          ],
        ),
      );
    }

    final sessions =
        _sessions
            .where((session) => session.category == _selectedCategory)
            .toList()
          ..sort((a, b) {
            final aTime = a.updatedAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.updatedAt?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });
    final accessibleSessions = _archiveUnlocked
        ? sessions
        : sessions
              .where(
                (session) => AppAdRewardService.instance.isSameLocalDay(
                  session.updatedAt,
                ),
              )
              .toList(growable: false);
    final lockedCount = sessions.length - accessibleSessions.length;
    final showLockedArchiveCard = lockedCount > 0 && !_archiveUnlocked;

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 8, 20, widget.bottomInset + 24),
        children: [
          if (sessions.isEmpty) ...[
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.16),
            _MessagesEmpty(category: _selectedCategory),
          ] else ...[
            if (accessibleSessions.isEmpty && showLockedArchiveCard) ...[
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
              _ArchiveUnlockCard(
                lockedCount: lockedCount,
                unlockInFlight: _unlockInFlight,
                onUnlock: _watchArchiveUnlockAd,
              ),
              const SizedBox(height: 18),
              const InlineAdBanner(),
            ] else
              for (
                var index = 0;
                index < accessibleSessions.length;
                index++
              ) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MessageSessionTile(
                    session: accessibleSessions[index],
                    locale: Localizations.localeOf(context).toString(),
                    onTap: () => _openSession(accessibleSessions[index]),
                  ),
                ),
                if (index == 0) ...[
                  const SizedBox(height: 4),
                  const InlineAdBanner(),
                  const SizedBox(height: 18),
                ],
              ],
            if (showLockedArchiveCard && accessibleSessions.isNotEmpty) ...[
              _ArchiveUnlockCard(
                lockedCount: lockedCount,
                unlockInFlight: _unlockInFlight,
                onUnlock: _watchArchiveUnlockAd,
              ),
            ],
          ],
        ],
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
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _kSecondary,
                      size: 20,
                    ),
                  ),
                ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  AppTexts.t('messages.title'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: GoogleFonts.newsreader(
                    fontSize: 48,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                    shadows: [
                      Shadow(
                        color: _kPrimary.withValues(alpha: 0.48),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _archiveCategories = <ArisSessionCategory>[
  ArisSessionCategory.tarot,
  ArisSessionCategory.coffee,
  ArisSessionCategory.palm,
  ArisSessionCategory.numerology,
];

String _archiveCategoryLabel(ArisSessionCategory category) =>
    switch (category) {
      ArisSessionCategory.tarot => AppTexts.t('archive.tab.tarot'),
      ArisSessionCategory.coffee => AppTexts.t('archive.tab.coffee'),
      ArisSessionCategory.palm => AppTexts.t('archive.tab.palm'),
      ArisSessionCategory.numerology => AppTexts.t(
        'home.cosmic.numerology.title',
      ),
    };

IconData _archiveCategoryIcon(ArisSessionCategory category) =>
    switch (category) {
      ArisSessionCategory.tarot => Icons.auto_awesome_rounded,
      ArisSessionCategory.coffee => Icons.local_cafe_rounded,
      ArisSessionCategory.palm => Icons.back_hand_rounded,
      ArisSessionCategory.numerology => Icons.calculate_rounded,
    };

class _ArchiveCategoryTabs extends StatelessWidget {
  const _ArchiveCategoryTabs({
    required this.selectedCategory,
    required this.onSelected,
  });

  final ArisSessionCategory selectedCategory;
  final ValueChanged<ArisSessionCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kBg.withValues(alpha: 0.82),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
        child: Row(
          children: [
            for (final category in _archiveCategories) ...[
              _ArchiveCategoryTab(
                category: category,
                selected: category == selectedCategory,
                onTap: () => onSelected(category),
              ),
              if (category != _archiveCategories.last)
                const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArchiveCategoryTab extends StatelessWidget {
  const _ArchiveCategoryTab({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ArisSessionCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _kTertiary : _kSecondary.withValues(alpha: 0.78);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? _kPrimary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? _kPrimary.withValues(alpha: 0.48)
                  : _kGlassBorder,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.18),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_archiveCategoryIcon(category), size: 17, color: color),
              const SizedBox(width: 7),
              Text(
                _archiveCategoryLabel(category),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: color,
                  decoration: TextDecoration.none,
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
    final title = switch (session.category) {
      ArisSessionCategory.coffee when session.cardNames.isEmpty => AppTexts.t(
        'archive.coffee_title',
      ),
      ArisSessionCategory.palm => AppTexts.t('archive.palm_title'),
      ArisSessionCategory.numerology => AppTexts.t('numerologyMadamArisTitle'),
      _ => session.titleLabel,
    };
    final icon = switch (session.category) {
      ArisSessionCategory.tarot when session.isSpread => Icons.style_rounded,
      _ => _archiveCategoryIcon(session.category),
    };
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
                  border: Border.all(color: _kPrimary.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: _kTertiary, size: 22),
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
                            title,
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
                        AppTexts.t(
                          'messages.thread_count',
                        ).replaceAll('{count}', '${session.messageCount}'),
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

class _ArchiveUnlockCard extends StatelessWidget {
  const _ArchiveUnlockCard({
    required this.lockedCount,
    required this.unlockInFlight,
    required this.onUnlock,
  });

  final int lockedCount;
  final bool unlockInFlight;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final body = AppTexts.t(
      'ads.archive.unlock_body',
    ).replaceAll('{count}', '$lockedCount');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _kGlassBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _kGlassBorder),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kPrimary.withValues(alpha: 0.16),
                    border: Border.all(
                      color: _kPrimary.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: _kTertiary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppTexts.t('ads.archive.unlock_title'),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kOnSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              body,
              style: GoogleFonts.manrope(
                fontSize: 14,
                height: 1.5,
                color: _kSecondary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: unlockInFlight ? null : onUnlock,
                icon: Icon(
                  unlockInFlight
                      ? Icons.hourglass_top_rounded
                      : Icons.smart_display_rounded,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary.withValues(alpha: 0.18),
                  foregroundColor: _kTertiary,
                  disabledBackgroundColor: _kPrimary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                label: Text(
                  unlockInFlight
                      ? AppTexts.t('common.loading')
                      : AppTexts.t('ads.archive.unlock_cta'),
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesEmpty extends StatelessWidget {
  const _MessagesEmpty({required this.category});

  final ArisSessionCategory category;

  @override
  Widget build(BuildContext context) {
    final bodyKey = switch (category) {
      ArisSessionCategory.tarot => 'archive.empty.tarot',
      ArisSessionCategory.coffee => 'archive.empty.coffee',
      ArisSessionCategory.palm => 'archive.empty.palm',
      ArisSessionCategory.numerology => 'home.cosmic.numerology.description',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _archiveCategoryIcon(category),
              size: 56,
              color: _kSecondary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              AppTexts.t(bodyKey),
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                fontSize: 26,
                fontStyle: FontStyle.italic,
                color: _kOnSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesError extends StatelessWidget {
  const _MessagesError({required this.message, this.onRetry});

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
              style: GoogleFonts.manrope(fontSize: 14, color: _kPrimary),
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
            colors: [_kBg, const Color(0xFF1A0B22), _kBg],
          ),
        ),
      ),
    );
  }
}
