import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_locale.dart';
import '../../core/app_texts.dart';
import '../../core/tarot_functions_client.dart';
import '../auth/user_profile_contract.dart';
import '../readings/tarot_card_view.dart';
import '../readings/tarot_service.dart';
import 'ai_chat_context.dart';
import 'aris_session_service.dart';

const _kBg = Color(0xFF17081C);
const _kPrimary = Color(0xFFFF5ED6);
const _kSecondary = Color(0xFFCDBDFF);
const _kTertiary = Color(0xFFFFE792);
const _kOnSurface = Color(0xFFFADCFF);
const _kGlass = Color(0x66361A41);
const _kConversationCost = 10;

class KozmikBilgePage extends StatefulWidget {
  const KozmikBilgePage({
    super.key,
    required this.uid,
    this.cardTitle = '',
    this.cardImageUrl = '',
    this.spreadCards = const [],
    this.spreadSessionId,
    this.resumeSessionId,
    this.chatContext,
  });

  final String uid;
  final String cardTitle;
  final String cardImageUrl;
  final List<DrawnTarotCard> spreadCards;
  final String? spreadSessionId;
  final String? resumeSessionId;
  final AiChatContext? chatContext;

  @override
  State<KozmikBilgePage> createState() => _KozmikBilgePageState();
}

class _KozmikBilgePageState extends State<KozmikBilgePage> {
  final _functionsClient = TarotFunctionsClient();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _random = math.Random();
  final List<_ArisChatMessage> _messages = [];

  String? _sessionId;
  bool _isLoadingOpening = true;
  bool _isSending = false;
  String? _openingError;

  @override
  void initState() {
    super.initState();
    final resumeId = widget.resumeSessionId?.trim() ?? '';
    if (resumeId.isNotEmpty) {
      _loadResumedSession(resumeId);
    } else {
      _loadOpeningReading();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    final contextImages = widget.chatContext?.contextImageFiles ?? const [];
    if (widget.chatContext?.ownsImageFile == true && contextImages.isNotEmpty) {
      unawaited(_deleteOwnedContextImages(contextImages));
    }
    super.dispose();
  }

  bool get _isCoffeeChat => widget.chatContext?.isCoffeeReading ?? false;

  bool get _isSpreadChat => widget.spreadCards.isNotEmpty;

  List<String> get _spreadCardNames => widget.spreadCards
      .map((card) => card.card.displayName.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);

  String? get _spreadCardNameJoined {
    final names = _spreadCardNames;
    if (names.isEmpty) return null;
    return names.join(', ');
  }

  String get _chatTitle =>
      widget.chatContext?.title ??
      (_isSpreadChat
          ? AppTexts.t('tarot.spread.chat_title')
          : AppTexts.t('arisTarotTitle'));

  String get _assistantName => _isCoffeeChat
      ? AppTexts.t('coffeeMadamArisName')
      : AppTexts.t('arisAssistantName');

  String get _loadingSubtitle => _isCoffeeChat
      ? AppTexts.t('coffeeLoadingChatSubtitle')
      : AppTexts.t('arisLoadingSubtitle');

  Future<void> _deleteOwnedContextImages(List<File> imageFiles) async {
    final seenPaths = <String>{};
    for (final imageFile in imageFiles) {
      if (!seenPaths.add(imageFile.path)) continue;
      try {
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (_) {}
    }
  }

  List<File> get _coffeeImageFiles {
    return widget.chatContext?.contextImageFiles ?? const [];
  }

  Map<String, dynamic> get _coffeeMetadata {
    return widget.chatContext?.metadata ?? const {};
  }

  int get _coffeeRequiredPhotoCount {
    return (_coffeeMetadata['requiredPhotoCount'] as num?)?.toInt() ?? 3;
  }

  int get _coffeePhotoCount => _coffeeImageFiles.length;

  String get _coffeeHeaderSubtitle {
    final subtitle = AppTexts.t('coffeeMadamArisSubtitle');
    if (_coffeePhotoCount >= _coffeeRequiredPhotoCount) return subtitle;
    return '$subtitle · $_coffeePhotoCount/$_coffeeRequiredPhotoCount';
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _mapOpeningError(FirebaseFunctionsException error) {
    final details = error.details?.toString().trim();
    final code = (error.message ?? details ?? error.code).trim();
    switch (code) {
      case 'GEMINI_API_KEY_MISSING':
        return AppTexts.t('aris.opening_error_api_key');
      case 'AUTH_REQUIRED':
      case 'unauthenticated':
        return AppTexts.t('aris.opening_error_auth');
      case 'USER_NOT_FOUND':
        return AppTexts.t('aris.opening_error_profile');
      case 'INVALID_ARIS_OPENING_INPUT':
        return AppTexts.t('aris.opening_error_input');
      case 'APP_CHECK_REQUIRED':
        return AppTexts.t('aris.opening_error_app_check');
      default:
        if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
          return AppTexts.t('aris.opening_error_network');
        }
        return AppTexts.t('aris.opening_error_generic');
    }
  }

  String _activeArisLanguage() {
    const supported = {'tr', 'en', 'de', 'es', 'fr', 'it', 'pt'};
    final appLang = AppLocale.current.trim().toLowerCase();
    if (supported.contains(appLang)) return appLang;

    final deviceLang =
        PlatformDispatcher.instance.locale.languageCode.trim().toLowerCase();
    if (supported.contains(deviceLang)) return deviceLang;
    return 'en';
  }

  Future<void> _loadResumedSession(String sessionId) async {
    if (mounted) {
      setState(() {
        _isLoadingOpening = true;
        _openingError = null;
      });
    }
    try {
      final record = await ArisSessionService().fetchSession(
        uid: widget.uid,
        sessionId: sessionId,
      );
      if (!mounted) return;
      if (record == null) {
        setState(() {
          _isLoadingOpening = false;
          _openingError = AppTexts.t('messages.resume_error');
        });
        return;
      }
      setState(() {
        _sessionId = record.sessionId;
        _messages.clear();
        if (record.openingMessage.isNotEmpty) {
          _messages.add(_ArisChatMessage.assistant(record.openingMessage));
        }
        for (final entry in record.recentMessages) {
          _messages.add(
            entry.isUser
                ? _ArisChatMessage.user(entry.text)
                : _ArisChatMessage.assistant(entry.text),
          );
        }
        _isLoadingOpening = false;
        _openingError = null;
      });
      _scrollToBottomSoon();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingOpening = false;
        _openingError = AppTexts.t('messages.resume_error');
      });
    }
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _loadOpeningReading() async {
    if (_isCoffeeChat) {
      await _loadCoffeeOpeningReading();
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingOpening = true;
        _openingError = null;
      });
    }
    try {
      if (_isSpreadChat && _spreadCardNames.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoadingOpening = false;
          _openingError = AppTexts.t('aris.opening_error_input');
        });
        return;
      }

      final spreadNames = _isSpreadChat ? _spreadCardNames : null;
      final singleName = widget.cardTitle.trim();
      final cardNames = spreadNames ??
          (singleName.isNotEmpty ? [singleName] : null);
      final cardNameForApi = spreadNames != null
          ? _spreadCardNameJoined
          : (singleName.isNotEmpty ? singleName : null);

      final response = await _functionsClient.generateArisOpeningReading(
        cardName: cardNameForApi,
        cardImageUrl: _isSpreadChat
            ? (widget.spreadCards.first.imageUrl)
            : widget.cardImageUrl,
        cardNames: cardNames,
        sessionId: widget.spreadSessionId,
        day: _todayKey(),
        lang: _activeArisLanguage(),
      );
      if (!mounted) return;
      final openingMessage =
          (response['openingMessage'] as String?)?.trim() ?? '';
      final sessionId = (response['sessionId'] as String?)?.trim() ?? '';
      setState(() {
        _sessionId = sessionId;
        _messages
          ..clear()
          ..add(_ArisChatMessage.assistant(openingMessage));
        _isLoadingOpening = false;
        _openingError = openingMessage.isEmpty ? 'Yorum alinamadi.' : null;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingOpening = false;
        _openingError = _mapOpeningError(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingOpening = false;
        _openingError = AppTexts.t('aris.opening_error_generic');
      });
    }
  }

  Future<void> _loadCoffeeOpeningReading() async {
    if (mounted) {
      setState(() {
        _isLoadingOpening = true;
        _openingError = null;
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    setState(() {
      _sessionId = 'mock_coffee_${DateTime.now().microsecondsSinceEpoch}';
      _messages
        ..clear()
        ..add(_ArisChatMessage.assistant(AppTexts.t('coffeeMockOpening')));
      _isLoadingOpening = false;
      _openingError = null;
    });
  }

  Future<void> _sendMessage(int credits) async {
    final text = _messageController.text.trim();
    if (_isSending || text.isEmpty || _sessionId == null) return;
    if (_isCoffeeChat) {
      await _sendCoffeeMessage(text);
      return;
    }
    if (credits < _kConversationCost) {
      await _showInsufficientCreditsDialog();
      return;
    }

    final idempotencyKey =
        'aris_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 20)}';
    setState(() {
      _isSending = true;
      _messageController.clear();
      _messages.add(_ArisChatMessage.user(text));
    });
    _scrollToBottom();

    try {
      final response = await _functionsClient.continueArisConversation(
        sessionId: _sessionId!,
        message: text,
        idempotencyKey: idempotencyKey,
        lang: _activeArisLanguage(),
      );
      final reply = (response['reply'] as String?)?.trim() ?? '';
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ArisChatMessage.assistant(
            reply.isEmpty ? 'Aris sessiz kaldi. Tekrar sorabilirsin.' : reply,
          ),
        );
      });
      _scrollToBottom();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      if (error.message == 'INSUFFICIENT_CREDITS') {
        await _showInsufficientCreditsDialog();
      } else {
        _showSnack('Mesaj gonderilemedi. Tekrar dene.');
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Mesaj gonderilemedi. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendCoffeeMessage(String text) async {
    setState(() {
      _isSending = true;
      _messageController.clear();
      _messages.add(_ArisChatMessage.user(text));
    });
    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;
    setState(() {
      _messages.add(_ArisChatMessage.assistant(_mockCoffeeReply(text)));
      _isSending = false;
    });
    _scrollToBottom();
  }

  String _mockCoffeeReply(String text) {
    final normalized = text.toLowerCase();
    if (normalized.contains('aşk') ||
        normalized.contains('ask') ||
        normalized.contains('love')) {
      return AppTexts.t('coffeeMockLoveReply');
    }
    if (normalized.contains('iş') ||
        normalized.contains('kariyer') ||
        normalized.contains('career') ||
        normalized.contains('para')) {
      return AppTexts.t('coffeeMockCareerReply');
    }
    return AppTexts.t('coffeeMockGeneralReply');
  }

  Future<void> _showInsufficientCreditsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF26112E),
          title: Text(
            'Jeton gerekli',
            style: GoogleFonts.spaceGrotesk(color: _kOnSurface),
          ),
          content: Text(
            'Bilge Aris ile sohbete devam etmek icin en az $_kConversationCost jeton gerekli.',
            style: GoogleFonts.manrope(color: _kSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Kapat'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop('credits');
              },
              child: const Text('Jeton Al'),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2E1537),
        ),
      );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final wallet = Map<String, dynamic>.from(
          data?[UserProfileContract.wallet] as Map? ?? const {},
        );
        final credits =
            (wallet[UserProfileContract.walletCredits] as num?)?.toInt() ?? 0;

        return Scaffold(
          backgroundColor: _kBg,
          body: Stack(
            children: [
              const _ChatBackground(),
              ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(24, topPadding + 92, 24, 170),
                children: [
                  if (_isCoffeeChat)
                    _MadamArisHero(
                      imageFiles: _coffeeImageFiles,
                      subtitle: _coffeeHeaderSubtitle,
                    )
                  else if (_isSpreadChat)
                    _TarotSpreadHero(cards: widget.spreadCards)
                  else
                    _HeroTarotCard(
                      cardTitle: widget.cardTitle,
                      cardImageUrl: widget.cardImageUrl,
                    ),
                  const SizedBox(height: 28),
                  if (_isCoffeeChat) ...[
                    const _CoffeeDisclaimerBanner(),
                    const SizedBox(height: 18),
                  ],
                  if (_isLoadingOpening)
                    _ArisLoadingBubble(
                      assistantName: _assistantName,
                      subtitle: _loadingSubtitle,
                    )
                  else if (_openingError != null)
                    _ArisErrorBubble(
                      message: _openingError!,
                      onRetry: _loadOpeningReading,
                    )
                  else
                    for (final message in _messages) ...[
                      _ArisMessageBubble(message: message),
                      const SizedBox(height: 8),
                    ],
                  if (!_isLoadingOpening && _openingError == null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _MessageMeta(assistantName: _assistantName),
                    ),
                  if (_isSending) ...[
                    const SizedBox(height: 12),
                    _ArisLoadingBubble(
                      compact: true,
                      assistantName: _assistantName,
                      subtitle: _loadingSubtitle,
                    ),
                  ],
                ],
              ),
              _ChatTopBar(credits: credits, title: _chatTitle),
              _ComposerArea(
                controller: _messageController,
                enabled: !_isLoadingOpening &&
                    _openingError == null &&
                    !_isSending &&
                    _sessionId != null,
                isSending: _isSending,
                costLabel: _isCoffeeChat
                    ? AppTexts.t('coffeeMessageNote')
                    : AppTexts.t('arisMessageCost'),
                hintText: _isCoffeeChat
                    ? AppTexts.t('coffeeQuestionHint')
                    : AppTexts.t('arisQuestionHint'),
                onSend: () => _sendMessage(credits),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({
    required this.credits,
    required this.title,
  });

  final int credits;
  final String title;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 12),
            decoration: BoxDecoration(
              color: _kBg.withValues(alpha: 0.82),
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.10),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: _kPrimary,
                    size: 24,
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      color: _kPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF361A41).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _kPrimary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    '$credits Jeton',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: _kPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroTarotCard extends StatelessWidget {
  const _HeroTarotCard({
    required this.cardTitle,
    required this.cardImageUrl,
  });

  final String cardTitle;
  final String cardImageUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 156,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.22),
                  blurRadius: 42,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: 0.04,
            child: SizedBox(
              width: 112,
              height: 176,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TarotCardView(
                      imageUrl: cardImageUrl,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(13),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: double.infinity,
                          color: Colors.black.withValues(alpha: 0.52),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            cardTitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.newsreader(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: _kTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarotSpreadHero extends StatelessWidget {
  const _TarotSpreadHero({required this.cards});

  final List<DrawnTarotCard> cards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: _kGlass,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.18),
            blurRadius: 40,
            spreadRadius: -12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTexts.t('tarot.spread.hero_title'),
            style: GoogleFonts.newsreader(
              color: _kPrimary,
              fontSize: 26,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppTexts.t('tarot.spread.hero_subtitle'),
            style: GoogleFonts.spaceGrotesk(
              color: _kSecondary.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final card = cards[index];
                return SizedBox(
                  width: 96,
                  child: _SpreadCardPlaceholder(title: card.card.displayName),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SpreadCardPlaceholder extends StatelessWidget {
  const _SpreadCardPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1235), Color(0xFF17081C)],
        ),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.28)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: _kOnSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _MadamArisHero extends StatelessWidget {
  const _MadamArisHero({
    required this.imageFiles,
    required this.subtitle,
  });

  final List<File> imageFiles;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: _kGlass,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withValues(alpha: 0.18),
              blurRadius: 40,
              spreadRadius: -12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const _MadamArisAvatar(size: 74),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTexts.t('coffeeMadamArisName'),
                        style: GoogleFonts.newsreader(
                          color: _kPrimary,
                          fontSize: 28,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.spaceGrotesk(
                          color: _kSecondary.withValues(alpha: 0.82),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (imageFiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var index = 0;
                      index < math.min(3, imageFiles.length);
                      index++) ...[
                    Expanded(
                      child: _CoffeeThumb(
                        file: imageFiles[index],
                        index: index,
                      ),
                    ),
                    if (index != math.min(3, imageFiles.length) - 1)
                      const SizedBox(width: 9),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoffeeThumb extends StatelessWidget {
  const _CoffeeThumb({
    required this.file,
    required this.index,
  });

  final File file;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              file,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.42),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '${index + 1}/3',
                  style: GoogleFonts.spaceGrotesk(
                    color: _kTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
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

class _MadamArisAvatar extends StatelessWidget {
  const _MadamArisAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.34),
                  blurRadius: 26,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: _kTertiary.withValues(alpha: 0.14),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          CustomPaint(
            size: Size.square(size),
            painter: _MadamArisAvatarPainter(),
          ),
        ],
      ),
    );
  }
}

class _MadamArisAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _kPrimary.withValues(alpha: 0.36),
          const Color(0xFF2E1537),
          const Color(0xFF120516),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawCircle(center, radius, bgPaint);

    final veilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _kPrimary.withValues(alpha: 0.72),
          const Color(0xFF32113C),
          const Color(0xFF140516),
        ],
      ).createShader(Offset.zero & size);

    final veil = Path()
      ..moveTo(size.width * 0.18, size.height * 0.70)
      ..quadraticBezierTo(
        size.width * 0.26,
        size.height * 0.14,
        size.width * 0.50,
        size.height * 0.10,
      )
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * 0.14,
        size.width * 0.82,
        size.height * 0.70,
      )
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.92,
        size.width * 0.18,
        size.height * 0.70,
      )
      ..close();
    canvas.drawPath(veil, veilPaint);

    final facePaint = Paint()..color = const Color(0xFFFFD3F7);
    final faceRect = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.42),
      width: size.width * 0.30,
      height: size.height * 0.36,
    );
    canvas.drawOval(faceRect, facePaint);

    final hairPaint = Paint()..color = const Color(0xFF24102B);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.35),
        width: size.width * 0.34,
        height: size.height * 0.22,
      ),
      math.pi,
      math.pi,
      true,
      hairPaint,
    );

    final eyePaint = Paint()
      ..color = const Color(0xFF430036)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.42, size.height * 0.42),
      Offset(size.width * 0.46, size.height * 0.42),
      eyePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.54, size.height * 0.42),
      Offset(size.width * 0.58, size.height * 0.42),
      eyePaint,
    );

    final shoulderPaint = Paint()
      ..color = const Color(0xFF4B185B).withValues(alpha: 0.9);
    final shoulders = Path()
      ..moveTo(size.width * 0.24, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.58,
        size.width * 0.76,
        size.height * 0.78,
      )
      ..lineTo(size.width * 0.76, size.height * 0.90)
      ..lineTo(size.width * 0.24, size.height * 0.90)
      ..close();
    canvas.drawPath(shoulders, shoulderPaint);

    final starPaint = Paint()..color = _kTertiary;
    _drawDiamond(
        canvas, Offset(size.width * 0.27, size.height * 0.30), 3.4, starPaint);
    _drawDiamond(
        canvas, Offset(size.width * 0.72, size.height * 0.26), 2.8, starPaint);
    _drawDiamond(
        canvas, Offset(size.width * 0.64, size.height * 0.64), 2.4, starPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = _kPrimary.withValues(alpha: 0.55);
    canvas.drawCircle(center, radius - 0.8, borderPaint);
  }

  void _drawDiamond(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CoffeeDisclaimerBanner extends StatelessWidget {
  const _CoffeeDisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _kGlass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _kTertiary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppTexts.t('coffeeEntertainmentDisclaimer'),
              style: GoogleFonts.manrope(
                color: _kSecondary.withValues(alpha: 0.78),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArisChatMessage {
  const _ArisChatMessage({
    required this.isUser,
    required this.text,
  });

  const _ArisChatMessage.user(String text) : this(isUser: true, text: text);
  const _ArisChatMessage.assistant(String text)
      : this(isUser: false, text: text);

  final bool isUser;
  final String text;
}

class _ArisMessageBubble extends StatelessWidget {
  const _ArisMessageBubble({required this.message});

  final _ArisChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(message.isUser ? 24 : 0),
            topRight: Radius.circular(message.isUser ? 0 : 24),
            bottomLeft: const Radius.circular(24),
            bottomRight: const Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: message.isUser
                    ? _kPrimary.withValues(alpha: 0.12)
                    : _kGlass,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(message.isUser ? 24 : 0),
                  topRight: Radius.circular(message.isUser ? 0 : 24),
                  bottomLeft: const Radius.circular(24),
                  bottomRight: const Radius.circular(24),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                message.text,
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                  color: _kOnSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArisLoadingBubble extends StatelessWidget {
  const _ArisLoadingBubble({
    this.compact = false,
    required this.assistantName,
    required this.subtitle,
  });

  final bool compact;
  final String assistantName;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 20,
          vertical: compact ? 12 : 18,
        ),
        decoration: BoxDecoration(
          color: _kGlass,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _kPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppTexts.t('arisTyping').replaceFirst(
                        '{name}',
                        assistantName,
                      ),
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        color: _kOnSurface,
                      ),
                    ),
                    const _TypingDots(),
                  ],
                ),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: _kSecondary.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dotCount = (_controller.value * 4).floor().clamp(1, 3);
        return SizedBox(
          width: 18,
          child: Text(
            '.' * dotCount,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              color: _kOnSurface,
            ),
          ),
        );
      },
    );
  }
}

class _ArisErrorBubble extends StatelessWidget {
  const _ArisErrorBubble({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kGlass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: GoogleFonts.manrope(color: _kOnSurface),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({required this.assistantName});

  final String assistantName;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppTexts.t('arisMessageMeta').replaceFirst('{name}', assistantName),
      style: GoogleFonts.spaceGrotesk(
        fontSize: 10,
        letterSpacing: 1.3,
        color: _kSecondary.withValues(alpha: 0.42),
      ),
    );
  }
}

class _ComposerArea extends StatelessWidget {
  const _ComposerArea({
    required this.controller,
    required this.enabled,
    required this.isSending,
    required this.costLabel,
    required this.hintText,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSending;
  final String costLabel;
  final String hintText;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(context).padding.bottom + 18,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _kBg.withValues(alpha: 0),
                  _kBg.withValues(alpha: 0.92),
                  _kBg,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    costLabel,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      letterSpacing: 1.1,
                      color: _kSecondary.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF361A41).withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          enabled: enabled,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSend(),
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: _kOnSurface,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            hintText: hintText,
                            hintStyle: GoogleFonts.manrope(
                              fontStyle: FontStyle.italic,
                              color: _kSecondary.withValues(alpha: 0.60),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: enabled ? onSend : null,
                        icon: isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _kPrimary,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_upward_rounded,
                                color: _kPrimary,
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
    );
  }
}

class _ChatBackground extends StatelessWidget {
  const _ChatBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: _kBg,
                gradient: RadialGradient(
                  center: Alignment(0.2, -0.3),
                  radius: 1.1,
                  colors: [Color(0xFF26112E), _kBg],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
