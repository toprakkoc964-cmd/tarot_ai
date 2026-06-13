import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';
import '../../core/localization_service.dart';
import 'personalization_question_config.dart';
import 'widgets/mystic_toast.dart';

class OnboardingFocusAreasPage extends StatefulWidget {
  const OnboardingFocusAreasPage({
    super.key,
    required this.onContinue,
    this.onBack,
    this.initialFocusAreas,
  });

  final void Function({required List<String> focusAreas}) onContinue;
  final VoidCallback? onBack;
  final List<String>? initialFocusAreas;

  @override
  State<OnboardingFocusAreasPage> createState() =>
      _OnboardingFocusAreasPageState();
}

class _OnboardingFocusAreasPageState extends State<OnboardingFocusAreasPage> {
  static const _bg = Color(0xFF17081C);
  static const _surface = Color(0xFF26112E);
  static const _surfaceHighest = Color(0xFF361A41);
  static const _primary = Color(0xFFFF5ED6);
  static const _primaryDeep = Color(0xFFFF00D4);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);
  static const _gold = Color(0xFFFFE792);

  late final Set<String> _focusAreas;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFocusAreas;
    _focusAreas = initial == null ? <String>{} : initial.toSet();
  }

  void _toggleArea(String id) {
    setState(() {
      if (_focusAreas.contains(id)) {
        _focusAreas.remove(id);
      } else {
        _focusAreas.add(id);
      }
    });
  }

  void _continue() {
    if (_focusAreas.isEmpty) {
      MysticToast.showError(context, AppTexts.t('error.profile_required'));
      return;
    }
    widget.onContinue(focusAreas: _focusAreas.toList(growable: false));
  }

  Widget _buildBackButton() {
    final onBack = widget.onBack;
    if (onBack == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
        label: Text(AppTexts.t('common.back')),
        style: TextButton.styleFrom(
          foregroundColor: _secondary.withValues(alpha: 0.82),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            AppTexts.t('onboarding.step3.subtitle_new'),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: _secondary.withValues(alpha: 0.88),
              fontSize: 17,
              height: 1.42,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: (_focusAreas.isEmpty ? _surface : _primary).withValues(
                alpha: _focusAreas.isEmpty ? 0.42 : 0.13,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: (_focusAreas.isEmpty ? _surfaceHighest : _primary)
                    .withValues(alpha: 0.56),
              ),
            ),
            child: Text(
              _focusAreas.isEmpty
                  ? AppTexts.t('onboarding.card_pick.hint')
                  : '${_focusAreas.length}/${PersonalizationQuestions.focusAreas.options.length}',
              style: GoogleFonts.spaceGrotesk(
                color: _focusAreas.isEmpty
                    ? _secondary.withValues(alpha: 0.86)
                    : _onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusGrid() {
    final options = PersonalizationQuestions.focusAreas.options;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: options.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: narrow ? 12 : 14,
            mainAxisSpacing: narrow ? 12 : 14,
            childAspectRatio: narrow ? 1.0 : 1.05,
          ),
          itemBuilder: (context, index) => _buildFocusCard(options[index]),
        );
      },
    );
  }

  Widget _buildFocusCard(PersonalizationOptionConfig option) {
    final selected = _focusAreas.contains(option.value);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleArea(option.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.32),
                    blurRadius: 30,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: _primaryDeep.withValues(alpha: 0.16),
                    blurRadius: 46,
                    spreadRadius: -4,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _primary.withValues(alpha: 0.35),
                          _surfaceHighest.withValues(alpha: 0.62),
                          _primaryDeep.withValues(alpha: 0.14),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _surface.withValues(alpha: 0.54),
                          _bg.withValues(alpha: 0.54),
                        ],
                      ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: selected
                      ? _primary.withValues(alpha: 0.72)
                      : _surfaceHighest.withValues(alpha: 0.52),
                  width: selected ? 1.25 : 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (selected)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 0.9,
                          colors: [
                            _primary.withValues(alpha: 0.24),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0.72,
                      duration: const Duration(milliseconds: 220),
                      child: AnimatedOpacity(
                        opacity: selected ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: _gold,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? _primary.withValues(alpha: 0.18)
                              : _surfaceHighest.withValues(alpha: 0.28),
                          border: Border.all(
                            color: selected
                                ? _primary.withValues(alpha: 0.50)
                                : _surfaceHighest.withValues(alpha: 0.54),
                          ),
                        ),
                        child: Icon(
                          option.icon,
                          size: 34,
                          color: selected ? _primary : _gold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          AppTexts.t(option.labelKey),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            color: selected ? _onSurface : _secondary,
                            letterSpacing: 2.4,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.18,
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
      ),
    );
  }

  Widget _buildContinueButton() {
    final hasSelection = _focusAreas.isNotEmpty;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(0, 12, 0, 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _continue,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: hasSelection ? 1 : 0.68,
              child: Container(
                height: 66,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasSelection
                        ? const [_primary, _primaryDeep]
                        : [
                            _primary.withValues(alpha: 0.72),
                            _primaryDeep.withValues(alpha: 0.72),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryDeep.withValues(alpha: 0.32),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppTexts.t('onboarding.step3.complete_profile'),
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF430036),
                        letterSpacing: 2.4,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF430036),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          widget.onBack == null ? 28 : 14,
          22,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBackButton(),
            if (widget.onBack != null) const SizedBox(height: 12),
            _buildIntro(),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildFocusGrid(),
              ),
            ),
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LocalizationService.instance.revision,
      builder: (context, _, __) => Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.2,
                  colors: [
                    Color(0xFF2E1537),
                    Color(0xFF17081C),
                    Color(0xFF17081C),
                  ],
                  stops: [0, 0.64, 1],
                ),
              ),
            ),
            _buildContent(),
          ],
        ),
      ),
    );
  }
}
