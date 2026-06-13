import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_locale.dart';
import '../../core/app_texts.dart';
import '../../core/localization_service.dart';
import 'auth_service.dart';
import 'user_profile_contract.dart';
import 'widgets/mystic_toast.dart';

class OnboardingNameBirthPage extends StatefulWidget {
  const OnboardingNameBirthPage({
    super.key,
    required this.authService,
    required this.uid,
    required this.onContinue,
    this.onBack,
  });

  final AuthService authService;
  final String uid;
  final void Function({
    required String name,
    required String birthDate,
    String? birthTime,
  })
  onContinue;
  final VoidCallback? onBack;

  @override
  State<OnboardingNameBirthPage> createState() =>
      _OnboardingNameBirthPageState();
}

class _OnboardingNameBirthPageState extends State<OnboardingNameBirthPage> {
  static const _bg = Color(0xFF17081C);
  static const _surfaceHigh = Color(0xFF361A41);
  static const _primary = Color(0xFFFF5ED6);
  static const _primaryDeep = Color(0xFFFF00D4);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);
  static const _gold = Color(0xFFFFE792);

  static const _trMonths = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();

  bool _isNameLocked = false;
  bool _appleNamePromptShown = false;

  DateTime _selectedDate = DateTime(2004, 3, 3, 12, 0);
  bool _timeSelected = false;
  bool _yearMode = false;

  double _dialAngle = 0.0;
  double _dialStartAngle = 0.0;
  double _dialAccum = 0.0;

  double get _degsPerUnit => _yearMode ? 10.0 : 5.0;

  @override
  void initState() {
    super.initState();
    _birthDateController.text = _storeDate(_selectedDate);
    _hydrateNameFromProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  String _displayDate(DateTime dt) {
    final lang = AppLocale.current;
    if (lang == 'tr') return '${dt.day} ${_trMonths[dt.month]} ${dt.year}';
    const enMonths = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${enMonths[dt.month]} ${dt.year}';
  }

  String _storeDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _storeTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _hydrateNameFromProfile() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(widget.uid)
          .get();

      final data = snapshot.data();
      final provider = (data?[UserProfileContract.provider] as String?) ?? '';
      final providers =
          (data?[UserProfileContract.providers] as List<dynamic>?)
              ?.whereType<String>()
              .toSet() ??
          currentUser.providerData
              .map((providerInfo) => providerInfo.providerId)
              .toSet();
      final isAppleUser =
          provider == 'apple.com' || providers.contains('apple.com');
      final firestoreDisplayName = UserProfileContract.normalizeName(
        (data?[UserProfileContract.displayName] as String?) ?? '',
      );
      final firestoreName = UserProfileContract.normalizeName(
        (data?[UserProfileContract.name] as String?) ?? '',
      );
      final authName = UserProfileContract.normalizeName(
        currentUser.displayName ?? '',
      );

      final resolvedName = firestoreDisplayName.isNotEmpty
          ? firestoreDisplayName
          : firestoreName.isNotEmpty
          ? firestoreName
          : authName;

      if (!mounted ||
          resolvedName.isEmpty ||
          _nameController.text.trim().isNotEmpty) {
        if (mounted && resolvedName.isEmpty && isAppleUser) {
          _promptForAppleDisplayName();
        }
        return;
      }
      setState(() {
        _nameController.text = resolvedName;
        _isNameLocked = true;
      });
    } catch (_) {
      // Keep name editable if profile prefill fails.
    }
  }

  Future<void> _promptForAppleDisplayName() async {
    if (_appleNamePromptShown || _nameController.text.trim().isNotEmpty) {
      return;
    }
    _appleNamePromptShown = true;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || _nameController.text.trim().isNotEmpty) return;

    final controller = TextEditingController();
    String? capturedName;
    try {
      if (!mounted) return;
      capturedName = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) {
          String? inputError;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              void submitName() {
                final normalized = UserProfileContract.normalizeName(
                  controller.text,
                );
                if (normalized.isEmpty) {
                  setDialogState(() {
                    inputError = AppTexts.t('error.profile_required');
                  });
                  return;
                }
                Navigator.of(dialogContext).pop(normalized);
              }

              return PopScope(
                canPop: false,
                child: AlertDialog(
                  backgroundColor: _surfaceHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: Text(
                    AppTexts.t('onboarding.apple_name_prompt_title'),
                    style: GoogleFonts.newsreader(
                      color: _onSurface,
                      fontSize: 26,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppTexts.t('onboarding.apple_name_prompt_body'),
                        style: GoogleFonts.manrope(
                          color: _secondary.withValues(alpha: 0.9),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: controller,
                        maxLength: UserProfileContract.maxNameLength,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.manrope(color: _onSurface),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: AppTexts.t('onboarding.name_hint'),
                          hintStyle: GoogleFonts.manrope(
                            color: _secondary.withValues(alpha: 0.5),
                          ),
                          errorText: inputError,
                          errorStyle: GoogleFonts.manrope(color: _primary),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.25),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: _secondary.withValues(alpha: 0.25),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: _primary,
                              width: 1.2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: _primary),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: _primary,
                              width: 1.2,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          if (inputError != null) {
                            setDialogState(() => inputError = null);
                          }
                        },
                        onSubmitted: (_) => submitName(),
                      ),
                    ],
                  ),
                  actions: [
                    FilledButton(
                      onPressed: submitName,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: const Color(0xFF430036),
                      ),
                      child: Text(
                        AppTexts.t('onboarding.apple_name_prompt_cta'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      controller.dispose();
    }

    final normalized = UserProfileContract.normalizeName(capturedName ?? '');
    if (!mounted || normalized.isEmpty) return;

    setState(() {
      _nameController.text = normalized;
      _isNameLocked = false;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    MysticToast.showError(context, message);
  }

  bool _validate() {
    if (_nameController.text.trim().isEmpty ||
        _birthDateController.text.trim().isEmpty) {
      _showError(AppTexts.t('error.profile_required'));
      return false;
    }
    return true;
  }

  void _continue() {
    if (!_validate()) return;
    widget.onContinue(
      name: _nameController.text.trim(),
      birthDate: _birthDateController.text.trim(),
      birthTime: _timeSelected ? _storeTime(_selectedDate) : null,
    );
  }

  void _onPanStart(DragStartDetails details, double half) {
    _dialStartAngle = math.atan2(
      details.localPosition.dy - half,
      details.localPosition.dx - half,
    );
    _dialAccum = 0;
  }

  void _onPanUpdate(DragUpdateDetails details, double half) {
    final cur = math.atan2(
      details.localPosition.dy - half,
      details.localPosition.dx - half,
    );
    var delta = cur - _dialStartAngle;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    _dialAccum += delta * (180 / math.pi);
    _dialStartAngle = cur;

    final units = (_dialAccum / _degsPerUnit).truncate();
    setState(() {
      _dialAngle += delta;
      if (units != 0) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          HapticFeedback.selectionClick();
        }
        if (_yearMode) {
          final newYear = (_selectedDate.year + units).clamp(
            1900,
            DateTime.now().year + 1,
          );
          _selectedDate = DateTime(
            newYear,
            _selectedDate.month,
            _selectedDate.day,
            _selectedDate.hour,
            _selectedDate.minute,
          );
        } else {
          _selectedDate = _selectedDate.add(Duration(days: units));
        }
        _birthDateController.text = _storeDate(_selectedDate);
        _dialAccum -= units * _degsPerUnit;
      }
    });
  }

  Future<void> _openDrumPicker() async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CosmicDrumPicker(
        initial: _selectedDate,
        timeSelected: _timeSelected,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedDate = result.date;
        _timeSelected = result.timeSelected;
        _birthDateController.text = _storeDate(_selectedDate);
      });
    }
  }

  InputDecoration _inputStyle({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: GoogleFonts.manrope(
      color: _onSurface.withValues(alpha: 0.38),
      fontSize: 15,
    ),
    labelStyle: GoogleFonts.spaceGrotesk(
      color: _secondary.withValues(alpha: 0.82),
      fontWeight: FontWeight.w700,
      letterSpacing: 2.2,
      fontSize: 11,
    ),
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.36),
    suffixIcon: suffixIcon,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: _secondary.withValues(alpha: 0.08)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: _secondary.withValues(alpha: 0.12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: const BorderSide(color: _primary, width: 1.2),
    ),
  );

  Widget _ghostRing(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: _gold.withValues(alpha: opacity), width: 1),
    ),
  );

  Widget _buildDial() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final d = (constraints.maxWidth * 0.82).clamp(230.0, 325.0);
        final half = d / 2;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppTexts.t('onboarding.birth_section_title'),
              style: GoogleFonts.spaceGrotesk(
                color: _secondary.withValues(alpha: 0.8),
                fontSize: 10,
                letterSpacing: 5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ModeChip(
                  label: AppTexts.t('onboarding.dial.mode_day'),
                  active: !_yearMode,
                  onTap: () => setState(() => _yearMode = false),
                ),
                const SizedBox(width: 10),
                _ModeChip(
                  label: AppTexts.t('onboarding.dial.mode_year'),
                  active: _yearMode,
                  onTap: () => setState(() => _yearMode = true),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onPanStart: (e) => _onPanStart(e, half),
              onPanUpdate: (e) => _onPanUpdate(e, half),
              onTap: _openDrumPicker,
              child: SizedBox(
                width: d + 28,
                height: d + 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _ghostRing(d + 26, 0.06),
                    _ghostRing(d + 12, 0.04),
                    Transform.rotate(
                      angle: _dialAngle,
                      child: CustomPaint(
                        size: Size(d, d),
                        painter: _DialPainter(
                          goldColor: _gold,
                          yearMode: _yearMode,
                        ),
                      ),
                    ),
                    Container(
                      width: 1.2,
                      height: d * 0.84,
                      color: _gold.withValues(alpha: 0.10),
                    ),
                    Container(
                      width: d * 0.84,
                      height: 1.2,
                      color: _gold.withValues(alpha: 0.10),
                    ),
                    Container(
                      width: d - 4,
                      height: d - 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.transparent,
                            _gold.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                    ),
                    if (_yearMode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.45),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(99),
                          color: _gold.withValues(alpha: 0.07),
                        ),
                        child: Text(
                          '${_selectedDate.year}',
                          style: GoogleFonts.newsreader(
                            color: _gold,
                            fontSize: d * 0.15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: d * 0.72,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _displayDate(_selectedDate),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.newsreader(
                                  color: _gold,
                                  fontSize: d * 0.135,
                                  fontWeight: FontWeight.w500,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _openDrumPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _timeSelected
                                      ? _gold.withValues(alpha: 0.5)
                                      : _secondary.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(99),
                                color: _timeSelected
                                    ? _gold.withValues(alpha: 0.07)
                                    : Colors.transparent,
                              ),
                              child: Text(
                                _timeSelected
                                    ? _storeTime(_selectedDate)
                                    : '+ ${AppTexts.t('onboarding.drum.add_time').toLowerCase()}',
                                style: GoogleFonts.spaceGrotesk(
                                  color: _timeSelected
                                      ? _gold.withValues(alpha: 0.85)
                                      : _secondary.withValues(alpha: 0.4),
                                  fontSize: _timeSelected ? 13 : 10,
                                  letterSpacing: _timeSelected ? 2 : 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    Positioned(
                      top: 2,
                      child: Container(
                        width: 3,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: _gold,
                          boxShadow: [
                            BoxShadow(
                              color: _gold.withValues(alpha: 0.7),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_yearMode) ...[
                      Positioned(
                        left: 0,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          color: _gold.withValues(alpha: 0.4),
                          size: 20,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: _gold.withValues(alpha: 0.4),
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _yearMode
                  ? AppTexts.t('onboarding.dial.caption_year')
                  : AppTexts.t('onboarding.dial.caption_day'),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: _secondary.withValues(alpha: 0.45),
                fontSize: 11,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.3,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton() {
    final hasBack = widget.onBack != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Row(
        children: [
          if (hasBack)
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
          if (hasBack) const SizedBox(width: 10),
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
          widget.onBack == null ? 26 : 12,
          22,
          MediaQuery.of(context).padding.bottom + 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.onBack != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onBack,
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
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      maxLength: UserProfileContract.maxNameLength,
                      readOnly: _isNameLocked,
                      canRequestFocus: !_isNameLocked,
                      showCursor: !_isNameLocked,
                      enableInteractiveSelection: !_isNameLocked,
                      style: GoogleFonts.manrope(
                        color: _onSurface,
                        fontSize: 16,
                      ),
                      decoration: _inputStyle(
                        label: AppTexts.t('onboarding.name_label_upper'),
                        hint: AppTexts.t('onboarding.name_hint'),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(
                            _isNameLocked
                                ? Icons.lock_rounded
                                : Icons.star_rate_rounded,
                            color: _gold.withValues(alpha: 0.65),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDial(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            _buildActionButton(),
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

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  static const _secondary = Color(0xFFCDBDFF);
  static const _gold = Color(0xFFFFE792);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minWidth: 90),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active
                ? _gold.withValues(alpha: 0.7)
                : _secondary.withValues(alpha: 0.2),
            width: 1,
          ),
          color: active ? _gold.withValues(alpha: 0.10) : Colors.transparent,
          boxShadow: active
              ? [BoxShadow(color: _gold.withValues(alpha: 0.2), blurRadius: 8)]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            color: active ? _gold : _secondary.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({required this.goldColor, required this.yearMode});

  final Color goldColor;
  final bool yearMode;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final paint = Paint()..style = PaintingStyle.stroke;

    paint
      ..color = goldColor.withValues(alpha: yearMode ? 0.6 : 0.45)
      ..strokeWidth = yearMode ? 1.2 : 1.0;
    canvas.drawCircle(center, r - 1, paint);

    final ticks = yearMode ? 12 : 60;
    final mainEvery = yearMode ? 1 : 5;
    for (int i = 0; i < ticks; i++) {
      final angle = i * (2 * math.pi / ticks) - math.pi / 2;
      final isMain = i % mainEvery == 0;
      final innerR = isMain ? r - 13 : r - 9;
      final inner = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );
      final outer = Offset(
        center.dx + (r - 2) * math.cos(angle),
        center.dy + (r - 2) * math.sin(angle),
      );
      paint
        ..color = goldColor.withValues(alpha: isMain ? 0.6 : 0.18)
        ..strokeWidth = isMain ? 1.4 : 0.7;
      canvas.drawLine(inner, outer, paint);
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2) - math.pi / 2;
      dotPaint.color = goldColor.withValues(alpha: i == 2 ? 0.55 : 0.82);
      final pos = Offset(
        center.dx + (r - 7) * math.cos(angle),
        center.dy + (r - 7) * math.sin(angle),
      );
      canvas.drawCircle(pos, yearMode ? 5 : 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.goldColor != goldColor || old.yearMode != yearMode;
}

class _PickerResult {
  const _PickerResult({required this.date, required this.timeSelected});

  final DateTime date;
  final bool timeSelected;
}

class _CosmicDrumPicker extends StatefulWidget {
  const _CosmicDrumPicker({required this.initial, required this.timeSelected});

  final DateTime initial;
  final bool timeSelected;

  @override
  State<_CosmicDrumPicker> createState() => _CosmicDrumPickerState();
}

class _CosmicDrumPickerState extends State<_CosmicDrumPicker> {
  static const _bg = Color(0xFF1E0C25);
  static const _primary = Color(0xFFFF5ED6);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);
  static const _gold = Color(0xFFFFE792);

  static const _trMonths = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  static const _enMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _deMonths = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];
  static const _esMonths = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  static const _frMonths = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  late int _day;
  late int _month;
  late int _year;
  late int _hour;
  late int _minute;
  late bool _showTime;

  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _yearCtrl;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minCtrl;

  static const _itemH = 46.0;
  static const _loopCenter = 60000;

  List<String> get _months {
    switch (AppLocale.current) {
      case 'tr':
        return _trMonths;
      case 'de':
        return _deMonths;
      case 'es':
        return _esMonths;
      case 'fr':
        return _frMonths;
      default:
        return _enMonths;
    }
  }

  int _daysInMonth(int month, int year) => DateTime(year, month + 1, 0).day;

  int _loopingInitialItem({
    required int itemCount,
    required int selectedIndex,
  }) {
    final base = _loopCenter - (_loopCenter % itemCount);
    return base + selectedIndex;
  }

  @override
  void initState() {
    super.initState();
    _day = widget.initial.day;
    _month = widget.initial.month;
    _year = widget.initial.year;
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
    _showTime = widget.timeSelected;

    _dayCtrl = FixedExtentScrollController(
      initialItem: _loopingInitialItem(itemCount: 31, selectedIndex: _day - 1),
    );
    _monthCtrl = FixedExtentScrollController(
      initialItem: _loopingInitialItem(
        itemCount: 12,
        selectedIndex: _month - 1,
      ),
    );
    _yearCtrl = FixedExtentScrollController(initialItem: _year - 1900);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  void _clampDay() {
    final max = _daysInMonth(_month, _year);
    if (_day > max) {
      _day = max;
      final current = _dayCtrl.hasClients ? _dayCtrl.selectedItem : _day - 1;
      final target = current - (current % 31) + (_day - 1);
      _dayCtrl.jumpToItem(target);
    }
  }

  Widget _drum({
    required int count,
    required String Function(int) label,
    required FixedExtentScrollController ctrl,
    required void Function(int) onChanged,
    double width = 72,
    bool looping = false,
  }) {
    final itemCount = looping ? 120000 : count;

    return SizedBox(
      width: width,
      height: _itemH * 5,
      child: Stack(
        children: [
          ListWheelScrollView.useDelegate(
            controller: ctrl,
            itemExtent: _itemH,
            perspective: 0.003,
            diameterRatio: 1.6,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) =>
                onChanged(looping ? index % count : index),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, index) {
                final realIndex = looping ? index % count : index;
                final selected = ctrl.hasClients ? ctrl.selectedItem : -1;
                final selectedRealIndex = selected >= 0
                    ? (looping ? selected % count : selected)
                    : -1;
                final sel = selectedRealIndex == realIndex;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label(realIndex),
                        maxLines: 1,
                        style: GoogleFonts.newsreader(
                          color: sel
                              ? _gold
                              : _onSurface.withValues(alpha: 0.3),
                          fontSize: sel ? 20 : 16,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IgnorePointer(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_bg, _bg.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
                Container(
                  height: _itemH,
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: _gold.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    color: _gold.withValues(alpha: 0.05),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [_bg, _bg.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: _secondary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.08),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _secondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFFF5ED6),
                    size: 14,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    AppTexts.t('onboarding.drum.title'),
                    style: GoogleFonts.spaceGrotesk(
                      color: _secondary,
                      fontSize: 12,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _drum(
                    count: 31,
                    label: (i) => '${i + 1}',
                    ctrl: _dayCtrl,
                    width: 52,
                    looping: true,
                    onChanged: (i) => setState(() {
                      _day = i + 1;
                      _clampDay();
                    }),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: _secondary.withValues(alpha: 0.15),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  _drum(
                    count: 12,
                    label: (i) => _months[i],
                    ctrl: _monthCtrl,
                    width: 132,
                    looping: true,
                    onChanged: (i) => setState(() {
                      _month = i + 1;
                      _clampDay();
                    }),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: _secondary.withValues(alpha: 0.15),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  _drum(
                    count: DateTime.now().year - 1900 + 2,
                    label: (i) => '${1900 + i}',
                    ctrl: _yearCtrl,
                    width: 72,
                    onChanged: (i) => setState(() {
                      _year = 1900 + i;
                      _clampDay();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _showTime = !_showTime),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showTime
                          ? Icons.access_time_filled_rounded
                          : Icons.access_time_rounded,
                      color: _showTime
                          ? _gold
                          : _secondary.withValues(alpha: 0.4),
                      size: 15,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _showTime
                          ? AppTexts.t('onboarding.drum.birth_time')
                          : AppTexts.t('onboarding.drum.add_time'),
                      style: GoogleFonts.spaceGrotesk(
                        color: _showTime
                            ? _gold
                            : _secondary.withValues(alpha: 0.4),
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showTime
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: _showTime
                          ? _gold
                          : _secondary.withValues(alpha: 0.4),
                      size: 15,
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: _showTime
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _drum(
                              count: 24,
                              label: (i) => i.toString().padLeft(2, '0'),
                              ctrl: _hourCtrl,
                              width: 52,
                              onChanged: (i) => setState(() => _hour = i),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                ':',
                                style: GoogleFonts.newsreader(
                                  color: _gold,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                            _drum(
                              count: 60,
                              label: (i) => i.toString().padLeft(2, '0'),
                              ctrl: _minCtrl,
                              width: 52,
                              onChanged: (i) => setState(() => _minute = i),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  _clampDay();
                  Navigator.of(context).pop(
                    _PickerResult(
                      date: DateTime(_year, _month, _day, _hour, _minute),
                      timeSelected: _showTime,
                    ),
                  );
                },
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5ED6), Color(0xFFFF00D4)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5ED6).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    AppTexts.t('onboarding.drum.confirm'),
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF430036),
                      fontSize: 13,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w800,
                    ),
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
