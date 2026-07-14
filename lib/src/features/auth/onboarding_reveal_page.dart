import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';
import '../../core/localization_service.dart';
import 'onboarding_card_pick_page.dart';

class OnboardingRevealPage extends StatefulWidget {
  const OnboardingRevealPage({
    super.key,
    required this.modality,
    required this.name,
    required this.birthDate,
    required this.focusAreas,
    required this.interpretationTone,
    required this.onContinue,
    this.onBack,
  });

  final OnboardingModality modality;
  final String name;
  final String birthDate;
  final Set<String> focusAreas;
  final String interpretationTone;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  @override
  State<OnboardingRevealPage> createState() => _OnboardingRevealPageState();
}

class _OnboardingRevealPageState extends State<OnboardingRevealPage>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF17081C);
  static const _surface = Color(0xFF1E0C25);
  static const _surfaceHigh = Color(0xFF361A41);
  static const _primary = Color(0xFFFF5ED6);
  static const _primaryDeep = Color(0xFFFF00D4);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);
  static const _gold = Color(0xFFFFE792);
  static const _outlineVariant = Color(0xFF5B3C66);
  static const _ctaText = Color(0xFF430036);

  final ScrollController _scrollController = ScrollController();
  final List<_RevealChatItem> _items = [];
  final List<Timer> _timers = [];

  late final AnimationController _bgController;
  late final AnimationController _typingController;
  late final AnimationController _artifactController;
  late _RevealScript _script;

  bool _started = false;
  bool _typing = false;
  bool _artifactVisible = false;
  bool _complete = false;
  bool _chipUsed = false;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _artifactController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _script = _RevealScript.build(
      modality: widget.modality,
      name: widget.name,
      birthDate: widget.birthDate,
      focusAreas: widget.focusAreas,
      interpretationTone: widget.interpretationTone,
    );
    _runScript();
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _scrollController.dispose();
    _bgController.dispose();
    _typingController.dispose();
    _artifactController.dispose();
    super.dispose();
  }

  Future<void> _runScript() async {
    await _appendArisMessage(_script.greeting, initialDelay: 420);
    await _showArtifact();
    for (final message in _script.interpretations) {
      await _appendArisMessage(message);
    }
    await _appendArisMessage(_script.closing, serif: true);
    await _appendArisMessage(AppTexts.t('onboarding.reveal.hook'));
    if (!mounted) return;
    setState(() => _complete = true);
    _scrollToBottom();
  }

  Future<void> _appendArisMessage(
    String text, {
    bool serif = false,
    int initialDelay = 220,
  }) async {
    await _delay(initialDelay);
    if (!mounted) return;
    setState(() => _typing = true);
    _scrollToBottom();
    await _delay(720 + math.min(text.length * 8, 520));
    if (!mounted) return;
    setState(() {
      _typing = false;
      _items.add(_RevealChatItem.aris(text, serif: serif));
    });
    _scrollToBottom();
  }

  Future<void> _showArtifact() async {
    await _delay(240);
    if (!mounted) return;
    setState(() {
      _artifactVisible = true;
      _items.add(_RevealChatItem.artifact(_script.artifact));
    });
    _artifactController.forward(from: 0);
    _scrollToBottom();
    await _delay(620);
  }

  Future<void> _handleChipTap(String chip) async {
    if (_chipUsed) return;
    setState(() {
      _chipUsed = true;
      _items.add(_RevealChatItem.user(chip));
    });
    _scrollToBottom();
    await _appendArisMessage(
      _template('onboarding.reveal.gating', {'name': _script.displayName}),
    );
    if (!mounted) return;
    setState(() => _complete = true);
  }

  Future<void> _delay(int milliseconds) {
    final completer = Completer<void>();
    final timer = Timer(Duration(milliseconds: milliseconds), () {
      if (!completer.isCompleted) completer.complete();
    });
    _timers.add(timer);
    return completer.future;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _template(String key, Map<String, String> values) {
    var text = AppTexts.t(key);
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LocalizationService.instance.revision,
      builder: (context, _, __) => Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            Positioned.fill(child: _background()),
            SafeArea(
              child: Column(
                children: [
                  _header(),
                  Expanded(child: _chatList()),
                  _bottomArea(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _background() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, _) {
        final value = Curves.easeInOut.transform(_bgController.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.7 - value * 0.3, -0.95 + value * 0.18),
              radius: 1.18,
              colors: const [
                Color(0xFF32133B),
                Color(0xFF17081C),
                Color(0xFF120516),
              ],
              stops: const [0, 0.62, 1],
            ),
          ),
          child: CustomPaint(painter: _RevealStarsPainter(value)),
        );
      },
    );
  }

  Widget _header() {
    final onBack = widget.onBack;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 18, 12),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: _secondary,
                size: 34,
              ),
            )
          else
            const SizedBox(width: 52),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _surface.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _outlineVariant.withValues(alpha: 0.52),
                    ),
                  ),
                  child: Row(
                    children: [
                      _avatar(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _script.personaName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.newsreader(
                                color: _onSurface,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _complete
                                  ? AppTexts.t('onboarding.reveal.status_ready')
                                  : _script.status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                color: _secondary.withValues(alpha: 0.86),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  Widget _avatar() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [_primary, _gold]),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.32),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: Image.asset(
          _script.assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_surfaceHigh, _bg]),
            ),
            alignment: Alignment.center,
            child: Text(
              _script.fallbackEmoji,
              style: const TextStyle(fontSize: 25),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      itemCount: _items.length + (_typing ? 1 : 0),
      itemBuilder: (context, index) {
        if (_typing && index == _items.length) {
          return _TypingBubble(controller: _typingController);
        }
        final item = _items[index];
        return switch (item.type) {
          _RevealChatItemType.aris => _ArisBubble(
            text: item.text,
            serif: item.serif,
          ),
          _RevealChatItemType.user => _UserBubble(text: item.text),
          _RevealChatItemType.artifact => _ArtifactBubble(
            artifact: item.artifact!,
            controller: _artifactController,
            visible: _artifactVisible,
          ),
        };
      },
    );
  }

  Widget _bottomArea() {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(20, 8, 20, math.max(16, bottom + 8)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: _complete && !_chipUsed
                ? _followUpChips()
                : const SizedBox.shrink(),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: _complete
                ? GestureDetector(
                    key: const ValueKey('reveal_cta'),
                    onTap: widget.onContinue,
                    child: Container(
                      height: 62,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primary, _primaryDeep],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryDeep.withValues(alpha: 0.36),
                            blurRadius: 24,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        _chipUsed
                            ? AppTexts.t('onboarding.reveal.cta_after_chip')
                            : AppTexts.t('onboarding.reveal.cta'),
                        style: GoogleFonts.spaceGrotesk(
                          color: _ctaText,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(height: 62),
          ),
        ],
      ),
    );
  }

  Widget _followUpChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        key: const ValueKey('reveal_chips'),
        children: [
          Text(
            AppTexts.t('onboarding.reveal.ask_label'),
            style: GoogleFonts.spaceGrotesk(
              color: _gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in _script.chips)
                GestureDetector(
                  onTap: () => _handleChipTap(chip),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceHigh.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.36),
                      ),
                    ),
                    child: Text(
                      chip,
                      style: GoogleFonts.manrope(
                        color: _onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _RevealChatItemType { aris, user, artifact }

class _RevealChatItem {
  const _RevealChatItem._({
    required this.type,
    required this.text,
    this.artifact,
    this.serif = false,
  });

  factory _RevealChatItem.aris(String text, {bool serif = false}) =>
      _RevealChatItem._(
        type: _RevealChatItemType.aris,
        text: text,
        serif: serif,
      );

  factory _RevealChatItem.user(String text) =>
      _RevealChatItem._(type: _RevealChatItemType.user, text: text);

  factory _RevealChatItem.artifact(_RevealArtifact artifact) =>
      _RevealChatItem._(
        type: _RevealChatItemType.artifact,
        text: artifact.title,
        artifact: artifact,
      );

  final _RevealChatItemType type;
  final String text;
  final _RevealArtifact? artifact;
  final bool serif;
}

class _ArisBubble extends StatelessWidget {
  const _ArisBubble({required this.text, required this.serif});

  final String text;
  final bool serif;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 46),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _OnboardingRevealPalette.surfaceHigh.withValues(alpha: 0.54),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(5),
          ),
          border: Border.all(
            color: _OnboardingRevealPalette.outline.withValues(alpha: 0.45),
          ),
        ),
        child: Text(
          text,
          style: serif
              ? GoogleFonts.newsreader(
                  color: _OnboardingRevealPalette.onSurface,
                  fontSize: 18,
                  height: 1.34,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                )
              : GoogleFonts.manrope(
                  color: _OnboardingRevealPalette.onSurface.withValues(
                    alpha: 0.92,
                  ),
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 58),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _OnboardingRevealPalette.primary.withValues(alpha: 0.34),
              _OnboardingRevealPalette.primaryDeep.withValues(alpha: 0.18),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(5),
          ),
          border: Border.all(
            color: _OnboardingRevealPalette.primary.withValues(alpha: 0.48),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.manrope(
            color: _OnboardingRevealPalette.onSurface,
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _OnboardingRevealPalette.surfaceHigh.withValues(alpha: 0.48),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(5),
          ),
          border: Border.all(
            color: _OnboardingRevealPalette.outline.withValues(alpha: 0.36),
          ),
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final phase = (controller.value + index * 0.18) % 1;
                final y = math.sin(phase * math.pi * 2) * 3;
                return Transform.translate(
                  offset: Offset(0, y),
                  child: Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _OnboardingRevealPalette.gold.withValues(
                        alpha: 0.55 + 0.35 * math.sin(phase * math.pi).abs(),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _ArtifactBubble extends StatelessWidget {
  const _ArtifactBubble({
    required this.artifact,
    required this.controller,
    required this.visible,
  });

  final _RevealArtifact artifact;
  final AnimationController controller;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final curved = Curves.easeOutBack.transform(controller.value);
        return Opacity(
          opacity: visible ? controller.value.clamp(0.0, 1.0) : 0,
          child: Transform.scale(scale: 0.82 + curved * 0.18, child: child),
        );
      },
      child: Center(
        child: Container(
          width: 240,
          margin: const EdgeInsets.only(bottom: 14, top: 2),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _OnboardingRevealPalette.surfaceHigh.withValues(alpha: 0.82),
                _OnboardingRevealPalette.bg.withValues(alpha: 0.84),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _OnboardingRevealPalette.gold.withValues(alpha: 0.42),
            ),
            boxShadow: [
              BoxShadow(
                color: _OnboardingRevealPalette.primary.withValues(alpha: 0.28),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(artifact.icon, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 10),
              Text(
                artifact.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  color: _OnboardingRevealPalette.gold,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                artifact.subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: _OnboardingRevealPalette.secondary.withValues(
                    alpha: 0.88,
                  ),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevealScript {
  const _RevealScript({
    required this.personaName,
    required this.assetPath,
    required this.fallbackEmoji,
    required this.status,
    required this.displayName,
    required this.greeting,
    required this.artifact,
    required this.interpretations,
    required this.closing,
    required this.chips,
  });

  factory _RevealScript.build({
    required OnboardingModality modality,
    required String name,
    required String birthDate,
    required Set<String> focusAreas,
    required String interpretationTone,
  }) {
    final displayName = name.trim().isEmpty
        ? AppTexts.t('onboarding.reveal.friend')
        : name.trim().split(RegExp(r'\s+')).first;
    final zodiac = _zodiacFromBirthDate(birthDate);
    final primaryFocus = focusAreas.isEmpty ? 'general' : focusAreas.first;
    final focusLabel = _focusLabel(primaryFocus);
    final personaName = modality == OnboardingModality.tarot
        ? AppTexts.t('onboarding.reveal.persona_bilge')
        : AppTexts.t('onboarding.reveal.persona_madam');
    final status = switch (modality) {
      OnboardingModality.tarot => AppTexts.t('onboarding.reveal.status_tarot'),
      OnboardingModality.coffee => AppTexts.t(
        'onboarding.reveal.status_coffee',
      ),
      OnboardingModality.palm => AppTexts.t('onboarding.reveal.status_palm'),
    };
    final artifact = _artifactFor(modality, birthDate, primaryFocus);
    final greeting = _template('onboarding.reveal.greeting', {
      'name': displayName,
      'persona': personaName,
    });
    final leadKey = switch (modality) {
      OnboardingModality.tarot => 'onboarding.reveal.interpretation_tarot',
      OnboardingModality.coffee => 'onboarding.reveal.interpretation_coffee',
      OnboardingModality.palm => 'onboarding.reveal.interpretation_palm',
    };
    final interpretations = [
      _template(leadKey, {
        'zodiac': zodiac,
        'focus': focusLabel.toLowerCase(),
        'artifact': artifact.title,
      }),
      _template('onboarding.reveal.interpretation_bridge', {
        'zodiac': zodiac,
        'focus': focusLabel.toLowerCase(),
      }),
    ];
    final closing = _template('onboarding.reveal.closing_$interpretationTone', {
      'name': displayName,
      'zodiac': zodiac,
      'focus': focusLabel.toLowerCase(),
    });
    return _RevealScript(
      personaName: personaName,
      assetPath: modality == OnboardingModality.tarot
          ? 'assets/onboarding/bilge_aris.png'
          : 'assets/onboarding/madam_aris.png',
      fallbackEmoji: switch (modality) {
        OnboardingModality.tarot => '🔮',
        OnboardingModality.coffee => '☕',
        OnboardingModality.palm => '✋',
      },
      status: status,
      displayName: displayName,
      greeting: greeting,
      artifact: artifact,
      interpretations: interpretations,
      closing: closing,
      chips: _chipsFor(primaryFocus),
    );
  }

  final String personaName;
  final String assetPath;
  final String fallbackEmoji;
  final String status;
  final String displayName;
  final String greeting;
  final _RevealArtifact artifact;
  final List<String> interpretations;
  final String closing;
  final List<String> chips;

  static String _template(String key, Map<String, String> values) {
    var text = AppTexts.t(key);
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }

  static String _focusLabel(String value) {
    final key = switch (value) {
      'love' => 'onboarding.step3.area.love',
      'career' => 'onboarding.step3.area.career',
      'money' => 'onboarding.step3.area.money',
      'spiritual' => 'onboarding.step3.area.spiritual',
      'family' => 'onboarding.step3.area.family',
      _ => 'onboarding.step3.area.general',
    };
    return AppTexts.t(key);
  }

  static _RevealArtifact _artifactFor(
    OnboardingModality modality,
    String birthDate,
    String focus,
  ) {
    final seed = (birthDate + focus).codeUnits.fold<int>(
      0,
      (previous, value) => previous + value,
    );
    final tarotPool = [
      _localizedArtifact('tarot.star', '✦'),
      _localizedArtifact('tarot.high_priestess', '☾'),
      _localizedArtifact('tarot.lovers', '♡'),
      _localizedArtifact('tarot.sun', '☀'),
    ];
    final coffeePool = [
      _localizedArtifact('coffee.bird', '☕'),
      _localizedArtifact('coffee.path', '☕'),
      _localizedArtifact('coffee.key', '☕'),
    ];
    final palmPool = [
      _localizedArtifact('palm.heart_line', '✋'),
      _localizedArtifact('palm.fate_line', '✋'),
      _localizedArtifact('palm.life_line', '✋'),
    ];
    final pool = switch (modality) {
      OnboardingModality.tarot => tarotPool,
      OnboardingModality.coffee => coffeePool,
      OnboardingModality.palm => palmPool,
    };
    return pool[seed % pool.length];
  }

  static _RevealArtifact _localizedArtifact(String key, String icon) {
    return _RevealArtifact(
      AppTexts.t('onboarding.reveal.artifact.$key.title'),
      AppTexts.t('onboarding.reveal.artifact.$key.subtitle'),
      icon,
    );
  }

  static List<String> _chipsFor(String focus) {
    if (focus == 'love') {
      return [
        AppTexts.t('onboarding.reveal.chip.love_1'),
        AppTexts.t('onboarding.reveal.chip.love_2'),
        AppTexts.t('onboarding.reveal.chip.love_3'),
      ];
    }
    if (focus == 'career' || focus == 'money') {
      return [
        AppTexts.t('onboarding.reveal.chip.career_1'),
        AppTexts.t('onboarding.reveal.chip.career_2'),
        AppTexts.t('onboarding.reveal.chip.career_3'),
      ];
    }
    return [
      AppTexts.t('onboarding.reveal.chip.default_1'),
      AppTexts.t('onboarding.reveal.chip.default_2'),
      AppTexts.t('onboarding.reveal.chip.default_3'),
    ];
  }

  static String _zodiacFromBirthDate(String birthDate) {
    final parsed = DateTime.tryParse(birthDate);
    if (parsed == null) return AppTexts.t('onboarding.reveal.zodiac_unknown');
    final month = parsed.month;
    final day = parsed.day;
    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return 'Koç';
    if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return 'Boğa';
    if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) {
      return 'İkizler';
    }
    if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) return 'Yengeç';
    if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return 'Aslan';
    if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return 'Başak';
    if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) {
      return 'Terazi';
    }
    if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) {
      return 'Akrep';
    }
    if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) return 'Yay';
    if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) return 'Oğlak';
    if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return 'Kova';
    return 'Balık';
  }
}

class _RevealArtifact {
  const _RevealArtifact(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final String icon;
}

class _RevealStarsPainter extends CustomPainter {
  const _RevealStarsPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 28; i++) {
      final x =
          ((i * 79.0) % size.width) + math.sin(progress * math.pi * 2 + i) * 8;
      final y = ((i * 113.0) % size.height);
      final blink =
          0.24 + 0.36 * math.sin(progress * math.pi * 2 + i * 0.7).abs();
      paint.color =
          (i.isEven
                  ? _OnboardingRevealPalette.gold
                  : _OnboardingRevealPalette.secondary)
              .withValues(alpha: blink);
      canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 1.8 : 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RevealStarsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _OnboardingRevealPalette {
  const _OnboardingRevealPalette._();

  static const bg = Color(0xFF17081C);
  static const surfaceHigh = Color(0xFF361A41);
  static const primary = Color(0xFFFF5ED6);
  static const primaryDeep = Color(0xFFFF00D4);
  static const secondary = Color(0xFFCDBDFF);
  static const onSurface = Color(0xFFFADCFF);
  static const gold = Color(0xFFFFE792);
  static const outline = Color(0xFF5B3C66);
}
