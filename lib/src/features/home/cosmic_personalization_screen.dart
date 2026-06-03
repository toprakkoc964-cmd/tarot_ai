import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';
import '../../core/theme/app_colors.dart';
import '../auth/personalization_question_config.dart';
import '../auth/user_profile_contract.dart';

class CosmicPersonalizationScreen extends StatefulWidget {
  const CosmicPersonalizationScreen({super.key, required this.uid});

  final String uid;

  @override
  State<CosmicPersonalizationScreen> createState() =>
      _CosmicPersonalizationScreenState();
}

class _CosmicPersonalizationScreenState
    extends State<CosmicPersonalizationScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _allowExit = false;
  String? _loadError;
  String? _relationshipStatus;
  String? _lifeSpace;
  String? _interpretationTone;
  bool _personalizationEnabled = true;
  final Set<String> _focusAreas = {};
  String _savedSignature = '';

  DocumentReference<Map<String, dynamic>> get _userDocRef => FirebaseFirestore
      .instance
      .collection(UserProfileContract.usersCollection)
      .doc(widget.uid);

  bool get _hasChanges => !_isLoading && _savedSignature != _currentSignature();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  String? _validSingleChoice(
    Object? raw,
    PersonalizationQuestionConfig config,
  ) {
    if (raw is! String) return null;
    return config.options.any((option) => option.value == raw) ? raw : null;
  }

  String _currentSignature() {
    final sortedFocusAreas = _focusAreas.toList()..sort();
    return [
      _relationshipStatus ?? '',
      _lifeSpace ?? '',
      _interpretationTone ?? '',
      _personalizationEnabled.toString(),
      sortedFocusAreas.join(','),
    ].join('|');
  }

  Future<void> _loadPreferences() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final snapshot = await _userDocRef.get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      final focusAreas =
          (data[UserProfileContract.focusAreas] as List?)
              ?.whereType<String>()
              .where(
                (value) => PersonalizationQuestions.focusAreas.options.any(
                  (option) => option.value == value,
                ),
              )
              .toSet() ??
          <String>{};

      if (focusAreas.isEmpty) focusAreas.add('general');
      if (!mounted) return;
      setState(() {
        _relationshipStatus = _validSingleChoice(
          data[UserProfileContract.relationshipStatus],
          PersonalizationQuestions.relationshipStatus,
        );
        _lifeSpace = _validSingleChoice(
          data[UserProfileContract.lifeSpace],
          PersonalizationQuestions.lifeSpace,
        );
        _interpretationTone = _validSingleChoice(
          data[UserProfileContract.interpretationTone],
          PersonalizationQuestions.interpretationTone,
        );
        _personalizationEnabled =
            data[UserProfileContract.personalizationEnabled] as bool? ?? true;
        _focusAreas
          ..clear()
          ..addAll(focusAreas);
        _savedSignature = _currentSignature();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = AppTexts.t('personalizationLoadError');
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _userDocRef.set({
        UserProfileContract.personalizationEnabled: _personalizationEnabled,
        UserProfileContract.relationshipStatus:
            _relationshipStatus ?? FieldValue.delete(),
        UserProfileContract.lifeSpace: _lifeSpace ?? FieldValue.delete(),
        UserProfileContract.interpretationTone:
            _interpretationTone ?? FieldValue.delete(),
        UserProfileContract.focusAreas: _focusAreas.toList()..sort(),
        UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _savedSignature = _currentSignature();
      _allowExit = true;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack(AppTexts.t('personalizationSaveError'));
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceHigh,
        ),
      );
  }

  Future<void> _requestExit() async {
    if (!_hasChanges) {
      _allowExit = true;
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(
          AppTexts.t('personalizationUnsavedTitle'),
          style: GoogleFonts.spaceGrotesk(color: AppColors.onSurface),
        ),
        content: Text(
          AppTexts.t('personalizationUnsavedMessage'),
          style: GoogleFonts.manrope(
            color: AppColors.secondaryLavender.withValues(alpha: 0.88),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppTexts.t('personalizationCancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryPink,
              foregroundColor: AppColors.onPrimary,
            ),
            child: Text(AppTexts.t('personalizationExit')),
          ),
        ],
      ),
    );

    if (!mounted || shouldExit != true) return;
    setState(() => _allowExit = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowExit || !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background.withValues(alpha: 0.94),
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _requestExit,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.primaryPink,
            ),
          ),
          title: Text(
            AppTexts.t('personalizationTitle'),
            style: GoogleFonts.newsreader(
              color: AppColors.primaryPink,
              fontSize: 28,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        body: SafeArea(top: false, child: _buildBody()),
        bottomNavigationBar: _isLoading || _loadError != null
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: AppColors.primaryPink,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor: AppColors.primaryPink.withValues(
                        alpha: 0.52,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      AppTexts.t(
                        _isSaving
                            ? 'personalizationSaving'
                            : 'personalizationSave',
                      ),
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPink),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(color: AppColors.onSurface),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadPreferences,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppTexts.t('common.retry')),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          AppTexts.t('personalizationDescription'),
          style: GoogleFonts.manrope(
            color: AppColors.secondaryLavender,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _GlassPanel(
          child: SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Text(
              AppTexts.t('personalizationEnabledTitle'),
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              AppTexts.t('personalizationEnabledSubtitle'),
              style: GoogleFonts.manrope(
                color: AppColors.secondaryLavender.withValues(alpha: 0.72),
                fontSize: 12,
              ),
            ),
            value: _personalizationEnabled,
            activeThumbColor: AppColors.primaryPink,
            onChanged: (value) =>
                setState(() => _personalizationEnabled = value),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedOpacity(
          opacity: _personalizationEnabled ? 1 : 0.54,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !_personalizationEnabled,
            child: Column(
              children: [
                for (final question in PersonalizationQuestions.editable) ...[
                  _QuestionPanel(
                    question: question,
                    selectedValues: _selectedValues(question),
                    onToggle: (value) => _toggle(question, value),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
        _GlassPanel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.tertiaryGold,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppTexts.t('personalizationPrivacyNote'),
                    style: GoogleFonts.manrope(
                      color: AppColors.secondaryLavender.withValues(
                        alpha: 0.82,
                      ),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Set<String> _selectedValues(PersonalizationQuestionConfig question) {
    switch (question.id) {
      case 'relationshipStatus':
        return {_relationshipStatus}.whereType<String>().toSet();
      case 'lifeSpace':
        return {_lifeSpace}.whereType<String>().toSet();
      case 'interpretationTone':
        return {_interpretationTone}.whereType<String>().toSet();
      case 'focusAreas':
        return _focusAreas;
      default:
        return const {};
    }
  }

  void _toggle(PersonalizationQuestionConfig question, String value) {
    setState(() {
      switch (question.id) {
        case 'relationshipStatus':
          _relationshipStatus = value;
          break;
        case 'lifeSpace':
          _lifeSpace = value;
          break;
        case 'interpretationTone':
          _interpretationTone = value;
          break;
        case 'focusAreas':
          if (_focusAreas.contains(value)) {
            if (_focusAreas.length > 1) _focusAreas.remove(value);
          } else {
            _focusAreas.add(value);
          }
          break;
      }
    });
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.question,
    required this.selectedValues,
    required this.onToggle,
  });

  final PersonalizationQuestionConfig question;
  final Set<String> selectedValues;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTexts.t(question.titleKey),
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.tertiaryGold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            if (question.subtitleKey != null) ...[
              const SizedBox(height: 6),
              Text(
                AppTexts.t(question.subtitleKey!),
                style: GoogleFonts.manrope(
                  color: AppColors.secondaryLavender.withValues(alpha: 0.7),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in question.options)
                  _OptionChip(
                    option: option,
                    isSelected: selectedValues.contains(option.value),
                    onTap: () => onToggle(option.value),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final PersonalizationOptionConfig option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryPink.withValues(alpha: 0.13)
              : AppColors.background.withValues(alpha: 0.44),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryPink.withValues(alpha: 0.65)
                : AppColors.glassBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryNeonPink.withValues(alpha: 0.18),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option.icon,
              size: 16,
              color: isSelected
                  ? AppColors.primaryPink
                  : AppColors.secondaryLavender,
            ),
            const SizedBox(width: 7),
            Text(
              AppTexts.t(option.labelKey),
              style: GoogleFonts.manrope(
                color: isSelected
                    ? AppColors.onSurface
                    : AppColors.secondaryLavender,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}
