import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';
import '../../core/localization_service.dart';
import 'personalization_question_config.dart';
import 'widgets/mystic_toast.dart';

class OnboardingPersonalizationPage extends StatefulWidget {
  const OnboardingPersonalizationPage({
    super.key,
    required this.onContinue,
    this.onBack,
    this.initialRelationshipStatus,
    this.initialLifeSpace,
    this.initialInterpretationTone,
  });

  final void Function({
    required String relationshipStatus,
    required String lifeSpace,
    required String interpretationTone,
  })
  onContinue;
  final VoidCallback? onBack;
  final String? initialRelationshipStatus;
  final String? initialLifeSpace;
  final String? initialInterpretationTone;

  @override
  State<OnboardingPersonalizationPage> createState() =>
      _OnboardingPersonalizationPageState();
}

class _OnboardingPersonalizationPageState
    extends State<OnboardingPersonalizationPage> {
  static const _bg = Color(0xFF17081C);
  static const _primary = Color(0xFFFF5ED6);
  static const _primaryDeep = Color(0xFFFF00D4);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);
  static const _gold = Color(0xFFFFE792);
  static const _outlineVariant = Color(0xFF5B3C66);

  String? _relationshipStatus;
  String? _lifeSpace;
  String? _interpretationTone;

  @override
  void initState() {
    super.initState();
    _relationshipStatus = widget.initialRelationshipStatus;
    _lifeSpace = widget.initialLifeSpace;
    _interpretationTone = widget.initialInterpretationTone;
  }

  void _showError(String message) {
    if (!mounted) return;
    MysticToast.showError(context, message);
  }

  void _continue() {
    final relationshipStatus = _relationshipStatus;
    final lifeSpace = _lifeSpace;
    final interpretationTone = _interpretationTone;
    if (relationshipStatus == null ||
        lifeSpace == null ||
        interpretationTone == null) {
      _showError(AppTexts.t('error.profile_required'));
      return;
    }
    widget.onContinue(
      relationshipStatus: relationshipStatus,
      lifeSpace: lifeSpace,
      interpretationTone: interpretationTone,
    );
  }

  Widget _pillChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? _primary.withValues(alpha: 0.10)
              : const Color(0xFF1E0C25),
          border: Border.all(
            color: selected
                ? _primary.withValues(alpha: 0.4)
                : _outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.3),
                    blurRadius: 15,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: selected ? _primary : _onSurface.withValues(alpha: 0.8),
            fontSize: 15,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _toneCard({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 140,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? _primary.withValues(alpha: 0.10)
                : const Color(0xFF1E0C25),
            border: Border.all(
              color: selected
                  ? _primary.withValues(alpha: 0.4)
                  : _outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? _primary : _secondary.withValues(alpha: 0.7),
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.manrope(
                  color: selected
                      ? _primary
                      : _onSurface.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 12),
        child: Text(
          text,
          style: GoogleFonts.spaceGrotesk(
            color: _gold,
            fontSize: 11,
            letterSpacing: 4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _sectionGroup({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [_sectionLabel(title), child],
    );
  }

  Widget _buildPersonalizationContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            AppTexts.t('onboarding.step2.subtitle_new'),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: _secondary.withValues(alpha: 0.8),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
        _sectionGroup(
          title: AppTexts.t('onboarding.step2.relationship'),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option
                  in PersonalizationQuestions.relationshipStatus.options)
                _pillChip(
                  label: AppTexts.t(option.labelKey),
                  selected: _relationshipStatus == option.value,
                  onTap: () =>
                      setState(() => _relationshipStatus = option.value),
                ),
            ],
          ),
        ),
        _sectionGroup(
          title: AppTexts.t('onboarding.step2.life_space'),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in PersonalizationQuestions.lifeSpace.options)
                _pillChip(
                  label: AppTexts.t(option.labelKey),
                  selected: _lifeSpace == option.value,
                  onTap: () => setState(() => _lifeSpace = option.value),
                ),
            ],
          ),
        ),
        _sectionGroup(
          title: AppTexts.t('onboarding.step2.tone'),
          child: Row(
            children: [
              for (final option
                  in PersonalizationQuestions.interpretationTone.options) ...[
                _toneCard(
                  icon: option.icon,
                  label: AppTexts.t(option.labelKey),
                  selected: _interpretationTone == option.value,
                  onTap: () =>
                      setState(() => _interpretationTone = option.value),
                ),
                if (option !=
                    PersonalizationQuestions.interpretationTone.options.last)
                  const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onBack,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _secondary.withValues(alpha: 0.45)),
                foregroundColor: _secondary,
                minimumSize: const Size.fromHeight(76),
                shape: const StadiumBorder(),
              ),
              child: Text(
                AppTexts.t('common.back'),
                style: GoogleFonts.spaceGrotesk(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _continue,
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _primaryDeep],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.45),
                      blurRadius: 26,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  AppTexts.t('onboarding.cta_continue'),
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF430036),
                    letterSpacing: 4,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          26,
          22,
          MediaQuery.of(context).padding.bottom + 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: _buildPersonalizationContent(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            _buildActions(),
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
        resizeToAvoidBottomInset: true,
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
