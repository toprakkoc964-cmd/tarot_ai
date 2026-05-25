import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_locale.dart';
import '../../core/tarot_functions_client.dart';
import '../auth/user_profile_contract.dart';
import '../readings/tarot_card_view.dart';

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
    required this.cardTitle,
    required this.cardImageUrl,
  });

  final String uid;
  final String cardTitle;
  final String cardImageUrl;

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
    _loadOpeningReading();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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

  Future<void> _loadOpeningReading() async {
    if (mounted) {
      setState(() {
        _isLoadingOpening = true;
        _openingError = null;
      });
    }
    try {
      final response = await _functionsClient.generateArisOpeningReading(
        cardName: widget.cardTitle,
        cardImageUrl: widget.cardImageUrl,
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingOpening = false;
        _openingError = 'Aris simdi yanit veremiyor. Lutfen tekrar dene.';
      });
    }
  }

  Future<void> _sendMessage(int credits) async {
    final text = _messageController.text.trim();
    if (_isSending || text.isEmpty || _sessionId == null) return;
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
                  _HeroTarotCard(
                    cardTitle: widget.cardTitle,
                    cardImageUrl: widget.cardImageUrl,
                  ),
                  const SizedBox(height: 28),
                  if (_isLoadingOpening)
                    const _ArisLoadingBubble()
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
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: _MessageMeta(),
                    ),
                  if (_isSending) ...[
                    const SizedBox(height: 12),
                    const _ArisLoadingBubble(compact: true),
                  ],
                ],
              ),
              _ChatTopBar(credits: credits),
              _ComposerArea(
                controller: _messageController,
                enabled: !_isLoadingOpening &&
                    _openingError == null &&
                    !_isSending &&
                    _sessionId != null,
                isSending: _isSending,
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
  const _ChatTopBar({required this.credits});

  final int credits;

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
                    'Kozmik Bilge Aris',
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
  const _ArisLoadingBubble({this.compact = false});

  final bool compact;

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
                      compact
                          ? 'Bilge Aris yaziyor'
                          : 'Bilge Aris yaziyor',
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
                    'Kartinin enerjisini topluyor.',
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
  const _MessageMeta();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Aris • Simdi',
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
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSending;
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
                    'Her mesaj $_kConversationCost jeton',
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
                            hintText: 'Bilgeye bir soru fisilda...',
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
