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
import 'onboarding_payload.dart';
import 'onboarding_step_three_section.dart';
import 'user_profile_contract.dart';

// ─────────────────────────────────────────────────────────────────────────────
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.authService,
    required this.uid,
  });
  final AuthService authService;
  final String uid;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingPageState extends State<OnboardingPage> {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF17081C);
  static const _surfaceHigh = Color(0xFF361A41);
  static const _primary = Color(0xFFFF5ED6);
  static const _primaryDeep = Color(0xFFFF00D4);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);
  static const _gold = Color(0xFFFFE792);
  static const _outlineVariant = Color(0xFF5B3C66);

  // ── Turkish month names ─────────────────────────────────────────────────
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

  // ── Services & controllers ───────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  bool _isNameLocked = false;

  // ── Flow state ───────────────────────────────────────────────────────────
  String _lang = 'tr';
  final String _selectedPersonaId = 'emilia';
  int _currentStep = 0;
  bool _loading = false;

  // ── Step 2 state ─────────────────────────────────────────────────────────
  String? _relationshipStatus;
  String? _lifeSpace;
  String? _interpretationTone;
  final Set<String> _focusAreas = {'love'};

  // ── Dial state ───────────────────────────────────────────────────────────
  DateTime _selectedDate = DateTime(2004, 3, 3, 12, 0);
  bool _timeSelected = false;
  bool _yearMode = false;

  double _dialAngle = 0.0;
  double _dialStartAngle = 0.0;
  double _dialAccum = 0.0;

  double get _degsPerUnit => _yearMode ? 10.0 : 5.0;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _lang = AppLocale.current;
    _birthDateController.text = _storeDate(_selectedDate);
    _hydrateNameFromProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _hydrateNameFromProfile() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(widget.uid)
          .get();

      final data = snapshot.data();
      final firestoreName = UserProfileContract.normalizeName(
        (data?[UserProfileContract.name] as String?) ?? '',
      );
      final authName = UserProfileContract.normalizeName(
        currentUser.displayName ?? '',
      );

      final resolvedName = firestoreName.isNotEmpty ? firestoreName : authName;

      if (!mounted || resolvedName.isEmpty) return;
      setState(() {
        _nameController.text = resolvedName;
        _isNameLocked = true;
      });
    } catch (_) {
      // Keep name editable if profile prefill fails.
    }
  }

  // ── Validation ───────────────────────────────────────────────────────────
  bool _validateStep(int step) {
    if (step == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError(AppTexts.t('error.profile_required'));
        return false;
      }
      if (_birthDateController.text.trim().isEmpty) {
        _showError('Dogum tarihi zorunlu.');
        return false;
      }
    }

    if (step == 1) {
      if (_relationshipStatus == null) {
        _showError('Lutfen iliski durumunu sec.');
        return false;
      }
      if (_lifeSpace == null) {
        _showError('Lutfen yasam alanini sec.');
        return false;
      }
      if (_interpretationTone == null) {
        _showError('Lutfen yorum tonunu sec.');
        return false;
      }
    }

    if (step == 2 && _focusAreas.isEmpty) {
      _showError('En az bir yorum konusu secmelisin.');
      return false;
    }
    return true;
  }

  void _nextStep() {
    if (!_validateStep(_currentStep)) return;
    if (_currentStep < 2) setState(() => _currentStep++);
  }

  void _previousStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submit() async {
    if (!_validateStep(0) || !_validateStep(1) || !_validateStep(2)) return;
    setState(() => _loading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'Oturum bulunamadi. Lutfen tekrar giris yap.',
        );
      }

      final userDocRef = FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(widget.uid);
      final existingDoc = await userDocRef.get();
      final existingData = existingDoc.data() ?? const <String, dynamic>{};

      final existingName = UserProfileContract.normalizeName(
        (existingData[UserProfileContract.name] as String?) ?? '',
      );
      final existingEmail =
          (existingData[UserProfileContract.email] as String?)?.trim() ?? '';

      final resolvedName = UserProfileContract.normalizeName(
        _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : (existingName.isNotEmpty
                ? existingName
                : (currentUser.displayName?.trim() ?? '')),
      );
      final resolvedEmail = (currentUser.email?.trim().isNotEmpty ?? false)
          ? currentUser.email!.trim()
          : existingEmail;

      if (resolvedName.isEmpty) {
        _showError('Ad soyad bilgisi zorunlu.');
        return;
      }

      final payload = OnboardingPayload(
        name: resolvedName,
        birthDate: _birthDateController.text.trim(),
        privacyAccepted: true,
        termsAccepted: true,
        aiProcessingAccepted: true,
        lang: _lang,
        selectedPersonaId: _selectedPersonaId,
        birthTime: _timeSelected ? _storeTime(_selectedDate) : null,
        relationshipStatus: _relationshipStatus,
        lifeSpace: _lifeSpace,
        interpretationTone: _interpretationTone,
        focusAreas: _focusAreas.toList(growable: false),
      );

      await userDocRef.set(
        payload.toUserDocumentMap(
          uid: widget.uid,
          email: resolvedEmail,
          isProfileComplete: true,
          includeCreatedAt: !existingDoc.exists,
        ),
        SetOptions(merge: true),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Dial pan ─────────────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails d, double half) {
    _dialStartAngle = math.atan2(
      d.localPosition.dy - half,
      d.localPosition.dx - half,
    );
    _dialAccum = 0;
  }

  void _onPanUpdate(DragUpdateDetails d, double half) {
    final cur = math.atan2(
      d.localPosition.dy - half,
      d.localPosition.dx - half,
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
          final newYear =
              (_selectedDate.year + units).clamp(1900, DateTime.now().year + 1);
          _selectedDate = DateTime(newYear, _selectedDate.month,
              _selectedDate.day, _selectedDate.hour, _selectedDate.minute);
        } else {
          _selectedDate = _selectedDate.add(Duration(days: units));
        }
        _birthDateController.text = _storeDate(_selectedDate);
        _dialAccum -= units * _degsPerUnit;
      }
    });
  }

  // ── Drum picker ──────────────────────────────────────────────────────────
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

  // ── Input style ──────────────────────────────────────────────────────────
  InputDecoration _inputStyle({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
            color: _onSurface.withValues(alpha: 0.38), fontSize: 15),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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

  // ── Top shell ────────────────────────────────────────────────────────────
  Widget _buildTopShell() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      color: _bg.withValues(alpha: 0.85),
      child: Row(
        children: [
          Image.asset(
            'images/chatgpt_logo.png',
            height: 34,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          Text(
            '${AppTexts.t('onboarding.step').toUpperCase()} '
            '${(_currentStep + 1).toString().padLeft(2, '0')} / 03',
            style: GoogleFonts.spaceGrotesk(
              color: _secondary.withValues(alpha: 0.6),
              fontSize: 10,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress bar ─────────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == _currentStep;
        final done = i < _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 4,
          width: active ? 48 : 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: active
                ? _primary
                : done
                    ? _primary.withValues(alpha: 0.2)
                    : _surfaceHigh,
            boxShadow: active
                ? [
                    BoxShadow(
                        color: _primary.withValues(alpha: 0.3), blurRadius: 15)
                  ]
                : null,
          ),
        );
      }),
    );
  }

  // ── Ghost ring helper ────────────────────────────────────────────────────
  Widget _ghostRing(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _gold.withValues(alpha: opacity), width: 1),
        ),
      );

  // ── Celestial dial ───────────────────────────────────────────────────────
  Widget _buildDial() {
    return LayoutBuilder(builder: (context, constraints) {
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
                      painter:
                          _DialPainter(goldColor: _gold, yearMode: _yearMode),
                    ),
                  ),
                  Container(
                      width: 1.2,
                      height: d * 0.84,
                      color: _gold.withValues(alpha: 0.10)),
                  Container(
                      width: d * 0.84,
                      height: 1.2,
                      color: _gold.withValues(alpha: 0.10)),
                  Container(
                    width: d - 4,
                    height: d - 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        Colors.transparent,
                        _gold.withValues(alpha: 0.04),
                      ]),
                    ),
                  ),
                  if (_yearMode)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _gold.withValues(alpha: 0.45), width: 1),
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
                                horizontal: 10, vertical: 3),
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
                              blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                  if (_yearMode) ...[
                    Positioned(
                      left: 0,
                      child: Icon(Icons.chevron_left_rounded,
                          color: _gold.withValues(alpha: 0.4), size: 20),
                    ),
                    Positioned(
                      right: 0,
                      child: Icon(Icons.chevron_right_rounded,
                          color: _gold.withValues(alpha: 0.4), size: 20),
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
    });
  }

  // ── Pill chip helper (Step 2 selectors) ──────────────────────────────────
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
                      color: _primary.withValues(alpha: 0.3), blurRadius: 15)
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

  // ── Tone card helper (Step 2: icon cards) ────────────────────────────────
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
                        color: _primary.withValues(alpha: 0.3), blurRadius: 15)
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color:
                      selected ? _primary : _secondary.withValues(alpha: 0.7),
                  size: 28),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.manrope(
                  color:
                      selected ? _primary : _onSurface.withValues(alpha: 0.8),
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

  // ── Section label helper ─────────────────────────────────────────────────
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

  // ── Step content ─────────────────────────────────────────────────────────
  Widget _buildStepContent() {
    // ── Step 0: Name + Dial ──────────────────────────────────────────────
    if (_currentStep == 0) {
      return Column(
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
            style: GoogleFonts.manrope(color: _onSurface, fontSize: 16),
            decoration: _inputStyle(
              label: AppTexts.t('onboarding.name_label_upper'),
              hint: AppTexts.t('onboarding.name_hint'),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  _isNameLocked ? Icons.lock_rounded : Icons.star_rate_rounded,
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
      );
    }

    // ── Step 1: Relationship + Life Space + Tone ────────────────────────
    if (_currentStep == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtitle
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
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

          // Relationship status
          _sectionLabel(AppTexts.t('onboarding.step2.relationship')),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pillChip(
                label: AppTexts.t('onboarding.step2.rel.single'),
                selected: _relationshipStatus == 'single',
                onTap: () => setState(() => _relationshipStatus = 'single'),
              ),
              _pillChip(
                label: AppTexts.t('onboarding.step2.rel.taken'),
                selected: _relationshipStatus == 'taken',
                onTap: () => setState(() => _relationshipStatus = 'taken'),
              ),
              _pillChip(
                label: AppTexts.t('onboarding.step2.rel.complicated'),
                selected: _relationshipStatus == 'complicated',
                onTap: () =>
                    setState(() => _relationshipStatus = 'complicated'),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Life space
          _sectionLabel(AppTexts.t('onboarding.step2.life_space')),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pillChip(
                label: AppTexts.t('onboarding.step2.life.student'),
                selected: _lifeSpace == 'student',
                onTap: () => setState(() => _lifeSpace = 'student'),
              ),
              _pillChip(
                label: AppTexts.t('onboarding.step2.life.corporate'),
                selected: _lifeSpace == 'corporate',
                onTap: () => setState(() => _lifeSpace = 'corporate'),
              ),
              _pillChip(
                label: AppTexts.t('onboarding.step2.life.creative'),
                selected: _lifeSpace == 'creative',
                onTap: () => setState(() => _lifeSpace = 'creative'),
              ),
              _pillChip(
                label: AppTexts.t('onboarding.step2.life.entrepreneur'),
                selected: _lifeSpace == 'entrepreneur',
                onTap: () => setState(() => _lifeSpace = 'entrepreneur'),
              ),
              _pillChip(
                label: AppTexts.t('onboarding.step2.life.freelance'),
                selected: _lifeSpace == 'freelance',
                onTap: () => setState(() => _lifeSpace = 'freelance'),
              ),
              _pillChip(
                label: AppTexts.t('onboarding.step2.life.other'),
                selected: _lifeSpace == 'other',
                onTap: () => setState(() => _lifeSpace = 'other'),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Interpretation tone
          _sectionLabel(AppTexts.t('onboarding.step2.tone')),
          Row(
            children: [
              _toneCard(
                icon: Icons.auto_awesome,
                label: AppTexts.t('onboarding.step2.tone.soft'),
                selected: _interpretationTone == 'soft',
                onTap: () => setState(() => _interpretationTone = 'soft'),
              ),
              const SizedBox(width: 10),
              _toneCard(
                icon: Icons.bolt,
                label: AppTexts.t('onboarding.step2.tone.direct'),
                selected: _interpretationTone == 'direct',
                onTap: () => setState(() => _interpretationTone = 'direct'),
              ),
              const SizedBox(width: 10),
              _toneCard(
                icon: Icons.temple_buddhist,
                label: AppTexts.t('onboarding.step2.tone.spiritual'),
                selected: _interpretationTone == 'spiritual',
                onTap: () => setState(() => _interpretationTone = 'spiritual'),
              ),
            ],
          ),
        ],
      );
    }

    // ── Step 2: Consent ─────────────────────────────────────────────────
    return OnboardingStepThreeSection(
      selectedFocusAreas: _focusAreas,
      onToggleArea: (id) {
        setState(() {
          if (_focusAreas.contains(id)) {
            _focusAreas.remove(id);
          } else {
            _focusAreas.add(id);
          }
        });
      },
      onSubmit: _submit,
      loading: _loading,
    );
  }

  // ── Bottom actions ────────────────────────────────────────────────────────
  Widget _buildActions() {
    if (_currentStep == 2) return const SizedBox.shrink();
    final isLast = _currentStep == 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Column(
        children: [
          Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _previousStep,
                    style: OutlinedButton.styleFrom(
                      side:
                          BorderSide(color: _secondary.withValues(alpha: 0.45)),
                      foregroundColor: _secondary,
                      minimumSize: const Size.fromHeight(76),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(AppTexts.t('common.back'),
                        style: GoogleFonts.spaceGrotesk(
                            letterSpacing: 2, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 10),
              Expanded(
                child: _loading
                    ? const Center(
                        child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : GestureDetector(
                        onTap: isLast ? _submit : _nextStep,
                        child: Container(
                          height: 76,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_primary, _primaryDeep]),
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
                            isLast
                                ? AppTexts.t('common.save_profile')
                                : AppTexts.t('onboarding.cta_continue'),
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
        ],
      ),
    );
  }

  Widget _buildStandardFlow() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopShell(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProgressBar(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: _buildStepContent(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildActions(),
                  const SizedBox(height: 2),
                  Text(
                    AppTexts.t('onboarding.footer'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: _secondary.withValues(alpha: 0.3),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.4,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepThreeFixedFlow() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopShell(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                16,
                22,
                MediaQuery.of(context).padding.bottom + 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProgressBar(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: _buildStepContent(),
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LocalizationService.instance.revision,
      builder: (context, _, __) => Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // Cosmic background
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
            // Content
            _currentStep == 2
                ? _buildStepThreeFixedFlow()
                : _buildStandardFlow(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mode chip (dial)
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
//  Dial CustomPainter
// ─────────────────────────────────────────────────────────────────────────────
class _DialPainter extends CustomPainter {
  final Color goldColor;
  final bool yearMode;

  const _DialPainter({required this.goldColor, required this.yearMode});

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
      final inner = Offset(center.dx + innerR * math.cos(angle),
          center.dy + innerR * math.sin(angle));
      final outer = Offset(center.dx + (r - 2) * math.cos(angle),
          center.dy + (r - 2) * math.sin(angle));
      paint
        ..color = goldColor.withValues(alpha: isMain ? 0.6 : 0.18)
        ..strokeWidth = isMain ? 1.4 : 0.7;
      canvas.drawLine(inner, outer, paint);
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2) - math.pi / 2;
      dotPaint.color = goldColor.withValues(alpha: i == 2 ? 0.55 : 0.82);
      final pos = Offset(center.dx + (r - 7) * math.cos(angle),
          center.dy + (r - 7) * math.sin(angle));
      canvas.drawCircle(pos, yearMode ? 5 : 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.goldColor != goldColor || old.yearMode != yearMode;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Picker result
// ─────────────────────────────────────────────────────────────────────────────
class _PickerResult {
  final DateTime date;
  final bool timeSelected;
  const _PickerResult({required this.date, required this.timeSelected});
}

// ─────────────────────────────────────────────────────────────────────────────
//  Cosmic Drum Picker (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────
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

  late int _day, _month, _year, _hour, _minute;
  late bool _showTime;

  late FixedExtentScrollController _dayCtrl,
      _monthCtrl,
      _yearCtrl,
      _hourCtrl,
      _minCtrl;

  static const _itemH = 46.0;
  static const _loopCenter = 60000;

  int _daysInMonth(int m, int y) => DateTime(y, m + 1, 0).day;

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
      initialItem:
          _loopingInitialItem(itemCount: 12, selectedIndex: _month - 1),
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
                          color:
                              sel ? _gold : _onSurface.withValues(alpha: 0.3),
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
                          color: _gold.withValues(alpha: 0.35), width: 1),
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
              spreadRadius: 10),
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
                  const Icon(Icons.auto_awesome,
                      color: Color(0xFFFF5ED6), size: 14),
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
                          })),
                  Container(
                      width: 1,
                      height: 60,
                      color: _secondary.withValues(alpha: 0.15),
                      margin: const EdgeInsets.symmetric(horizontal: 6)),
                  _drum(
                      count: 12,
                      label: (i) => _months[i],
                      ctrl: _monthCtrl,
                      width: 132,
                      looping: true,
                      onChanged: (i) => setState(() {
                            _month = i + 1;
                            _clampDay();
                          })),
                  Container(
                      width: 1,
                      height: 60,
                      color: _secondary.withValues(alpha: 0.15),
                      margin: const EdgeInsets.symmetric(horizontal: 6)),
                  _drum(
                      count: DateTime.now().year - 1900 + 2,
                      label: (i) => '${1900 + i}',
                      ctrl: _yearCtrl,
                      width: 72,
                      onChanged: (i) => setState(() {
                            _year = 1900 + i;
                            _clampDay();
                          })),
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
                      color:
                          _showTime ? _gold : _secondary.withValues(alpha: 0.4),
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
                      color:
                          _showTime ? _gold : _secondary.withValues(alpha: 0.4),
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
                                onChanged: (i) => setState(() => _hour = i)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(':',
                                  style: GoogleFonts.newsreader(
                                      color: _gold, fontSize: 28)),
                            ),
                            _drum(
                                count: 60,
                                label: (i) => i.toString().padLeft(2, '0'),
                                ctrl: _minCtrl,
                                width: 52,
                                onChanged: (i) => setState(() => _minute = i)),
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
                    gradient: const LinearGradient(colors: [
                      Color(0xFFFF5ED6),
                      Color(0xFFFF00D4),
                    ]),
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
