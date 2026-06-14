import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_language.dart';
import '../../core/app_locale.dart';
import '../../core/app_texts.dart';
import '../../core/localization_service.dart';
import '../../core/notification_service.dart' as fcm_notifications;
import '../auth/auth_service.dart';
import '../auth/user_profile_contract.dart';
import '../auth/verify_email_page.dart';
import '../auth/widgets/mystic_toast.dart';
import '../settings/notification_settings_page.dart';
import 'cosmic_personalization_screen.dart';

const _kBg = Color(0xFF17081C);
const _kPrimary = Color(0xFFFF5ED6);
const _kSecondary = Color(0xFFCDBDFF);
const _kTertiary = Color(0xFFFFE792);
const _kOnSurface = Color(0xFFFADCFF);
const _kOutlineVariant = Color(0xFF5B3C66);
const _kError = Color(0xFFFD6F85);

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.bottomInset,
    required this.authService,
    required this.uid,
  });

  final double bottomInset;
  final AuthService authService;
  final String uid;

  static double topBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top + 64;
  }

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _notificationsEnabled = true;
  String _name = 'Toprak Koc';
  DateTime _birthDate = DateTime(1996, 2, 14);
  String _email = 'ornek@email.com';
  String _languageCode = AppLocale.current;
  bool _profileLoading = true;
  bool _isGuestProfile = false;
  bool _upgradeInProgress = false;

  DocumentReference<Map<String, dynamic>> get _userDocRef => FirebaseFirestore
      .instance
      .collection(UserProfileContract.usersCollection)
      .doc(widget.uid);

  @override
  void initState() {
    super.initState();
    _loadProfileFromFirestore();
  }

  DateTime? _parseStoredBirthDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  String _toStoredBirthDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _loadProfileFromFirestore() async {
    try {
      final snap = await _userDocRef.get();
      final data = snap.data();
      if (!mounted || data == null) return;

      final storedName = UserProfileContract.normalizeName(
        (data[UserProfileContract.name] as String?) ?? '',
      );
      final storedEmail =
          (data[UserProfileContract.email] as String?)?.trim() ?? '';
      final authUser = FirebaseAuth.instance.currentUser;
      final storedIsGuest = data[UserProfileContract.isGuest] == true;
      final storedBirthDate = _parseStoredBirthDate(
        data[UserProfileContract.birthDate] as String?,
      );
      final notificationPrefs =
          data[UserProfileContract.notificationPrefs] as Map<String, dynamic>?;
      final storedNotificationsEnabled = notificationPrefs?['enabled'] as bool?;
      final storedLanguage = (data[UserProfileContract.language] as String?)
          ?.trim();

      setState(() {
        if (storedName.isNotEmpty) _name = storedName;
        if (storedEmail.isNotEmpty) _email = storedEmail;
        _isGuestProfile = authUser?.isAnonymous == true || storedIsGuest;
        if (storedBirthDate != null) _birthDate = storedBirthDate;
        if (storedNotificationsEnabled != null) {
          _notificationsEnabled = storedNotificationsEnabled;
        }
        if (storedLanguage != null && AppLanguage.isSupported(storedLanguage)) {
          _languageCode = AppLanguage.normalize(storedLanguage);
        }
      });
    } catch (_) {
      // Keep UI defaults if read fails.
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _updateProfileFields(Map<String, dynamic> fields) async {
    await _userDocRef.set({
      ...fields,
      UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> _docRefForUid(String uid) =>
      FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(uid);

  bool _isSocialCancel(Object error) {
    if (error is! FirebaseAuthException) return false;
    final code = error.code.toLowerCase();
    return code == 'social-auth-cancelled' ||
        code == 'canceled' ||
        code == 'cancelled' ||
        code == 'user-cancelled' ||
        code == 'sign_in_canceled';
  }

  Future<void> _markCurrentUserLinked({
    required String provider,
    required List<String> providers,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final email = (user.email ?? '').trim();
    final displayName = UserProfileContract.normalizeName(
      user.displayName ?? '',
    );
    await _docRefForUid(user.uid).set({
      UserProfileContract.uid: user.uid,
      if (email.isNotEmpty) UserProfileContract.email: email,
      if (displayName.isNotEmpty) UserProfileContract.name: displayName,
      UserProfileContract.provider: provider,
      UserProfileContract.providers: providers,
      UserProfileContract.providerVerified: true,
      UserProfileContract.emailVerified: true,
      UserProfileContract.isGuest: false,
      UserProfileContract.accountStatus: UserProfileContract.statusActive,
      UserProfileContract.cleanupEligible: false,
      UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _showGuestUpgradeSheet() async {
    if (_upgradeInProgress) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _GuestUpgradeSheet(
        isLoading: _upgradeInProgress,
        onApple: () {
          Navigator.of(sheetContext).pop();
          _upgradeGuestWithApple();
        },
        onGoogle: () {
          Navigator.of(sheetContext).pop();
          _upgradeGuestWithGoogle();
        },
        onEmail: () {
          Navigator.of(sheetContext).pop();
          _showGuestEmailUpgradeSheet();
        },
      ),
    );
  }

  Future<void> _upgradeGuestWithGoogle() async {
    if (_upgradeInProgress) return;
    setState(() => _upgradeInProgress = true);
    try {
      await widget.authService.linkOrSignInWithGoogle();
      await _markCurrentUserLinked(
        provider: 'google.com',
        providers: const ['google.com'],
      );
      if (!mounted) return;
      _showSnack(AppTexts.t('profile.guest.upgrade_success'));
      await _loadProfileFromFirestore();
    } catch (error) {
      if (!mounted || _isSocialCancel(error)) return;
      _showSnack(AppTexts.t('profile.guest.upgrade_error'));
    } finally {
      if (mounted) setState(() => _upgradeInProgress = false);
    }
  }

  Future<void> _upgradeGuestWithApple() async {
    if (_upgradeInProgress) return;
    setState(() => _upgradeInProgress = true);
    try {
      await widget.authService.linkOrSignInWithApple();
      await _markCurrentUserLinked(
        provider: 'apple.com',
        providers: const ['apple.com'],
      );
      if (!mounted) return;
      _showSnack(AppTexts.t('profile.guest.upgrade_success'));
      await _loadProfileFromFirestore();
    } catch (error) {
      if (!mounted || _isSocialCancel(error)) return;
      _showSnack(AppTexts.t('profile.guest.upgrade_error'));
    } finally {
      if (mounted) setState(() => _upgradeInProgress = false);
    }
  }

  Future<void> _showGuestEmailUpgradeSheet() async {
    if (_upgradeInProgress) return;
    final input = await showModalBottomSheet<_GuestEmailUpgradeInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GuestEmailUpgradeSheet(),
    );
    if (!mounted || input == null) return;
    await _upgradeGuestWithEmail(input);
  }

  Future<void> _upgradeGuestWithEmail(_GuestEmailUpgradeInput input) async {
    if (_upgradeInProgress) return;
    final email = input.email.trim();
    final password = input.password;
    final confirmPassword = input.confirmPassword;
    if (email.isEmpty || !email.contains('@')) {
      _showSnack(AppTexts.t('auth.register.invalid_email'));
      return;
    }
    if (password.length < 6) {
      _showSnack(AppTexts.t('profile.guest.password_short'));
      return;
    }
    if (password != confirmPassword) {
      _showSnack(AppTexts.t('profile.guest.password_mismatch'));
      return;
    }

    setState(() => _upgradeInProgress = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !user.isAnonymous) {
        throw FirebaseAuthException(code: 'missing-guest-user');
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      final result = await user.linkWithCredential(credential);
      final linkedUser = result.user ?? FirebaseAuth.instance.currentUser;
      if (linkedUser == null) {
        throw FirebaseAuthException(code: 'missing-linked-user');
      }
      await linkedUser.sendEmailVerification();
      await _docRefForUid(linkedUser.uid).set({
        UserProfileContract.uid: linkedUser.uid,
        UserProfileContract.email: email,
        UserProfileContract.provider: 'password',
        UserProfileContract.providers: const ['password'],
        UserProfileContract.emailVerified: linkedUser.emailVerified,
        UserProfileContract.providerVerified: false,
        UserProfileContract.isGuest: false,
        UserProfileContract.accountStatus:
            UserProfileContract.statusPendingEmailVerification,
        UserProfileContract.cleanupEligible: true,
        UserProfileContract.verificationEmailSentAt:
            FieldValue.serverTimestamp(),
        UserProfileContract.verificationDeadlineAt: Timestamp.fromDate(
          DateTime.now().add(
            const Duration(hours: AuthService.verificationTtlHours),
          ),
        ),
        UserProfileContract.verificationResendCount: 0,
        UserProfileContract.verificationResendWindowStartedAt:
            FieldValue.serverTimestamp(),
        UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _email = email;
        _isGuestProfile = false;
      });
      _showSnack(AppTexts.t('profile.guest.upgrade_email_sent'));
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => VerifyEmailPage(
            authService: widget.authService,
            user: linkedUser,
            onVerified: () {
              Navigator.of(context, rootNavigator: true).maybePop();
              _loadProfileFromFirestore();
            },
            onChangeEmail: () {
              Navigator.of(context, rootNavigator: true).maybePop();
              _showGuestEmailUpgradeSheet();
            },
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'email-already-in-use' ||
          error.code == 'credential-already-in-use') {
        _showSnack(AppTexts.t('profile.guest.email_in_use'));
      } else {
        _showSnack(AppTexts.t('profile.guest.upgrade_error'));
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack(AppTexts.t('profile.guest.upgrade_error'));
    } finally {
      if (mounted) setState(() => _upgradeInProgress = false);
    }
  }

  Future<void> _openNotificationSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationSettingsPage(uid: widget.uid),
      ),
    );
    if (!mounted) return;
    await _loadProfileFromFirestore();
  }

  String _formatBirthDate(DateTime dt) {
    const trMonths = [
      '',
      'Ocak',
      'Subat',
      'Mart',
      'Nisan',
      'Mayis',
      'Haziran',
      'Temmuz',
      'Agustos',
      'Eylul',
      'Ekim',
      'Kasim',
      'Aralik',
    ];
    const enMonths = [
      '',
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
    const deMonths = [
      '',
      'Januar',
      'Februar',
      'Maerz',
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
    const esMonths = [
      '',
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
    const frMonths = [
      '',
      'janvier',
      'fevrier',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'aout',
      'septembre',
      'octobre',
      'novembre',
      'decembre',
    ];
    final months = switch (AppLocale.current) {
      'tr' => trMonths,
      'de' => deMonths,
      'es' => esMonths,
      'fr' => frMonths,
      _ => enMonths,
    };
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  double _heroNameFontSize(String value) {
    final length = value.trim().length;
    if (length <= 12) return 50;
    if (length <= 18) return 42;
    if (length <= 26) return 34;
    return 28;
  }

  void _showSnack(String message) {
    MysticToast.showInfo(context, message);
  }

  Future<void> _editNameBottomSheet() async {
    final controller = TextEditingController(text: _name);
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF26112E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _kSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppTexts.t('profile.name.edit_title'),
              style: GoogleFonts.newsreader(
                fontSize: 28,
                fontStyle: FontStyle.italic,
                color: _kOnSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppTexts.t('profile.name.edit_hint'),
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: _kOnSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 30,
              style: GoogleFonts.manrope(color: _kOnSurface, fontSize: 16),
              decoration: InputDecoration(
                counterText: '',
                hintText: AppTexts.t('profile.name.placeholder'),
                hintStyle: GoogleFonts.manrope(
                  color: _kOnSurface.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.28),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: _kSecondary.withValues(alpha: 0.15),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: _kSecondary.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: _kPrimary, width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) {
                    Navigator.of(sheetContext).pop(value);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: const Color(0xFF430036),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  AppTexts.t('common.save_profile'),
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted || saved == null) return;
    final normalized = UserProfileContract.normalizeName(saved);
    if (normalized.isEmpty) return;
    setState(() => _name = normalized);
    try {
      await _updateProfileFields({UserProfileContract.name: normalized});
      _showSnack(AppTexts.t('profile.name.updated'));
    } catch (e) {
      _showSnack(
        AppTexts.t('profile.name.save_error').replaceAll('{error}', '$e'),
      );
    }
  }

  Future<void> _pickBirthDateSheet() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BirthDatePickerSheet(initial: _birthDate),
    );

    if (!mounted || picked == null) return;
    setState(() => _birthDate = picked);
    try {
      await _updateProfileFields({
        UserProfileContract.birthDate: _toStoredBirthDate(picked),
      });
      _showSnack(AppTexts.t('profile.birth.updated'));
    } catch (e) {
      _showSnack(
        AppTexts.t('profile.birth.save_error').replaceAll('{error}', '$e'),
      );
    }
  }

  Future<void> _editEmailPage() async {
    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => _EmailEditPage(initialEmail: _email)),
    );

    final normalized = updated?.trim() ?? '';
    if (!mounted || normalized.isEmpty) return;
    setState(() => _email = normalized);
    try {
      await _updateProfileFields({UserProfileContract.email: normalized});
      _showSnack(AppTexts.t('profile.email.updated'));
    } catch (e) {
      _showSnack(
        AppTexts.t('profile.email.save_error').replaceAll('{error}', '$e'),
      );
    }
  }

  Future<void> _pickLanguage() async {
    final options = AppLanguage.supported;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF26112E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                AppTexts.t('common.select_language'),
                style: GoogleFonts.spaceGrotesk(
                  color: _kOnSurface,
                  fontSize: 14,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            for (final code in options)
              ListTile(
                onTap: () => Navigator.of(sheetContext).pop(code),
                leading: Icon(
                  code == _languageCode
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: code == _languageCode ? _kPrimary : _kSecondary,
                ),
                title: Text(
                  AppLanguage.displayName(code),
                  style: GoogleFonts.manrope(color: _kOnSurface),
                ),
              ),
          ],
        ),
      ),
    );

    if (!mounted || selected == null || selected == _languageCode) return;

    try {
      await LocalizationService.instance.setLanguage(selected);
      await _updateProfileFields({UserProfileContract.language: selected});
      await fcm_notifications.NotificationService.instance
          .syncNotificationContextForCurrentUser();
      if (!mounted) return;
      setState(() => _languageCode = selected);
      _showSnack(
        AppTexts.t(
          'profile.language.updated',
        ).replaceAll('{language}', AppLanguage.displayName(selected)),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(AppTexts.t('profile.language.save_error'));
    }
  }

  Future<void> _openCosmicPersonalization() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CosmicPersonalizationScreen(uid: widget.uid),
      ),
    );
    if (!mounted || saved != true) return;
    _showSnack(AppTexts.t('personalizationSaved'));
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF26112E),
        title: Text(
          AppTexts.t('profile.logout.confirm_title'),
          style: GoogleFonts.spaceGrotesk(color: _kOnSurface),
        ),
        content: Text(
          AppTexts.t('profile.logout.confirm_body'),
          style: GoogleFonts.manrope(color: _kOnSurface.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              AppTexts.t('common.cancel'),
              style: GoogleFonts.manrope(color: _kSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: const Color(0xFF430036),
            ),
            child: Text(AppTexts.t('profile.logout.confirm_action')),
          ),
        ],
      ),
    );

    if (!mounted || confirm != true) return;
    try {
      await widget.authService.signOut();
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        AppTexts.t('profile.logout.failed').replaceAll('{error}', '$e'),
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF26112E),
        title: Text(
          AppTexts.t('profile.delete.confirm_title'),
          style: GoogleFonts.spaceGrotesk(color: _kOnSurface),
        ),
        content: Text(
          AppTexts.t('profile.delete.confirm_body'),
          style: GoogleFonts.manrope(color: _kOnSurface.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              AppTexts.t('profile.delete.confirm_cancel'),
              style: GoogleFonts.manrope(color: _kSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _kError,
              foregroundColor: const Color(0xFF490013),
            ),
            child: Text(AppTexts.t('profile.delete.confirm_action')),
          ),
        ],
      ),
    );

    if (!mounted || confirm != true) return;
    Future<void> forceSignOut() async {
      try {
        await widget.authService.signOut(redirectToLogin: false);
      } catch (_) {}
    }

    widget.authService.accountDeletionInProgress.value = true;
    try {
      await widget.authService.markPostDeletionRedirectPending();
      await widget.authService.deleteCurrentUserCompletely();
      if (mounted) {
        _showSnack(AppTexts.t('profile.delete.success'));
      }
      await forceSignOut();
    } catch (e) {
      await widget.authService.clearPostDeletionRedirect();
      if (mounted) {
        _showSnack(
          AppTexts.t('profile.delete.failed').replaceAll('{error}', '$e'),
        );
      }
    } finally {
      widget.authService.accountDeletionInProgress.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LocalizationService.instance.revision,
      builder: (context, _, __) => _buildProfile(context),
    );
  }

  Widget _buildProfile(BuildContext context) {
    if (_profileLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        const _ProfileBackground(),
        ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            ProfilePage.topBarHeight(context) + 20,
            24,
            widget.bottomInset + 24,
          ),
          children: [
            _buildHero(),
            const SizedBox(height: 28),
            _buildSectionTitle(AppTexts.t('profile.section.identity')),
            _buildGlassCard(
              children: [
                _ProfileInfoRow(
                  label: AppTexts.t('profile.field.name'),
                  value: _name,
                  onTap: _editNameBottomSheet,
                ),
                _ProfileInfoRow(
                  label: AppTexts.t('profile.field.birth_date'),
                  value: _formatBirthDate(_birthDate),
                  onTap: _pickBirthDateSheet,
                ),
                _ProfileInfoRow(
                  label: AppTexts.t('profile.field.email'),
                  value: _isGuestProfile
                      ? AppTexts.t('profile.guest.upgrade_value')
                      : _email,
                  onTap: _isGuestProfile
                      ? _showGuestUpgradeSheet
                      : _editEmailPage,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildSectionTitle(AppTexts.t('profile.section.preferences')),
            _buildGlassCard(
              children: [
                _ActionRow(
                  icon: Icons.language_rounded,
                  title: AppTexts.t('profile.language.title'),
                  onTap: _pickLanguage,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLanguage.displayName(_languageCode),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: _kSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 20,
                        color: _kOutlineVariant,
                      ),
                    ],
                  ),
                ),
                _ActionRow(
                  icon: Icons.notifications_rounded,
                  title: AppTexts.t('notificationSettingsTitle'),
                  subtitle: _notificationsEnabled
                      ? AppTexts.t('notificationSettingsEnabled')
                      : AppTexts.t('notificationSettingsDisabled'),
                  onTap: _openNotificationSettings,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: _kSecondary.withValues(alpha: 0.85),
                  ),
                ),
                _ActionRow(
                  icon: Icons.auto_awesome_rounded,
                  title: AppTexts.t('profileCosmicPersonalizationTitle'),
                  subtitle: AppTexts.t('profileCosmicPersonalizationSubtitle'),
                  onTap: _openCosmicPersonalization,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildSectionTitle(AppTexts.t('profile.section.purchases')),
            _buildGlassCard(
              children: [
                _ActionRow(
                  icon: Icons.history_rounded,
                  title: AppTexts.t('profile.purchases.history'),
                  onTap: () => _showSnack(
                    AppTexts.t('profile.purchases.history_opening'),
                  ),
                ),
                _ActionRow(
                  icon: Icons.card_membership_rounded,
                  title: AppTexts.t('profile.purchases.manage_subscription'),
                  onTap: () => _showSnack(
                    AppTexts.t('profile.purchases.manage_subscription_opening'),
                  ),
                ),
                _ActionRow(
                  icon: Icons.restore_rounded,
                  title: AppTexts.t('profile.purchases.restore'),
                  onTap: () => _showSnack(
                    AppTexts.t('profile.purchases.restore_started'),
                  ),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 30),
            OutlinedButton(
              onPressed: _confirmLogout,
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF361A41).withValues(alpha: 0.4),
                side: BorderSide(color: _kSecondary.withValues(alpha: 0.25)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                AppTexts.t('profile.logout.confirm_action'),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  letterSpacing: 2.0,
                  color: _kOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _confirmDeleteAccount,
                child: Text(
                  AppTexts.t('profile.delete.confirm_action'),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: _kError.withValues(alpha: 0.85),
                    decoration: TextDecoration.underline,
                    decorationColor: _kError.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Positioned(top: 0, left: 0, right: 0, child: _ProfileTopBar()),
      ],
    );
  }

  Widget _buildHero() {
    final displayName = _name.trim().isEmpty ? 'Toprak Koc' : _name.trim();
    final heroFontSize = _heroNameFontSize(displayName);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.newsreader(
              fontSize: heroFontSize,
              height: 0.96,
              fontWeight: FontWeight.w600,
              color: _kOnSurface,
              letterSpacing: -1.0,
              shadows: [
                Shadow(
                  color: _kPrimary.withValues(alpha: 0.22),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppTexts.t('profile.hero.subtitle'),
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: _kOnSurface.withValues(alpha: 0.72),
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          letterSpacing: 3.0,
          color: _kSecondary.withValues(alpha: 0.6),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGlassCard({required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF361A41).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _kOnSurface.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.05),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ),
    );
  }
}

class _BirthDatePickerSheet extends StatefulWidget {
  const _BirthDatePickerSheet({required this.initial});

  final DateTime initial;

  @override
  State<_BirthDatePickerSheet> createState() => _BirthDatePickerSheetState();
}

class _BirthDatePickerSheetState extends State<_BirthDatePickerSheet> {
  static const _bg = Color(0xFF1E0C25);
  static const _primary = Color(0xFFFF5ED6);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);
  static const _gold = Color(0xFFFFE792);
  static const _itemH = 46.0;
  static const _loopCenter = 60000;

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

  late int _day, _month, _year;
  late FixedExtentScrollController _dayCtrl, _monthCtrl, _yearCtrl;

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
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
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
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  _clampDay();
                  Navigator.of(context).pop(DateTime(_year, _month, _day));
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

class _EmailEditPage extends StatefulWidget {
  const _EmailEditPage({required this.initialEmail});

  final String initialEmail;

  @override
  State<_EmailEditPage> createState() => _EmailEditPageState();
}

class _EmailEditPageState extends State<_EmailEditPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialEmail,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          AppTexts.t('profile.email.edit_title'),
          style: GoogleFonts.spaceGrotesk(fontSize: 14, letterSpacing: 1.2),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTexts.t('profile.email.edit_hint'),
              style: GoogleFonts.manrope(
                color: _kOnSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.manrope(color: _kOnSurface, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'ornek@email.com',
                hintStyle: GoogleFonts.manrope(
                  color: _kOnSurface.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _kSecondary.withValues(alpha: 0.25),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _kSecondary.withValues(alpha: 0.25),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kPrimary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(_controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: const Color(0xFF430036),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  AppTexts.t('common.save_profile'),
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
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

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, topPadding + 10, 24, 10),
          decoration: BoxDecoration(
            color: _kBg.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(color: _kSecondary.withValues(alpha: 0.1)),
            ),
          ),
          child: Text(
            AppTexts.t('home.profile.title'),
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              fontSize: 34,
              fontStyle: FontStyle.italic,
              color: _kPrimary,
              shadows: [
                Shadow(
                  color: _kPrimary.withValues(alpha: 0.45),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBackground extends StatelessWidget {
  const _ProfileBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Container(color: _kBg),
            Positioned(
              top: 120,
              right: -110,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.1),
                      blurRadius: 100,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -110,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kSecondary.withValues(alpha: 0.08),
                      blurRadius: 100,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.isLast = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: _kTertiary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: _kOnSurface,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _kOutlineVariant,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(color: _kOutlineVariant.withValues(alpha: 0.2), height: 1),
      ],
    );
  }
}

class _GuestEmailUpgradeInput {
  const _GuestEmailUpgradeInput({
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  final String email;
  final String password;
  final String confirmPassword;
}

class _GuestUpgradeSheet extends StatelessWidget {
  const _GuestUpgradeSheet({
    required this.isLoading,
    required this.onApple,
    required this.onGoogle,
    required this.onEmail,
  });

  final bool isLoading;
  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              decoration: BoxDecoration(
                color: const Color(0xFF26112E).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _kPrimary.withValues(alpha: 0.28),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kPrimary.withValues(alpha: 0.16),
                    blurRadius: 34,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _kSecondary.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppTexts.t('profile.guest.upgrade_title'),
                    style: GoogleFonts.newsreader(
                      fontSize: 30,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: _kOnSurface,
                      shadows: [
                        Shadow(
                          color: _kPrimary.withValues(alpha: 0.22),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppTexts.t('profile.guest.upgrade_subtitle'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      height: 1.45,
                      color: _kOnSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _GuestUpgradeAction(
                    icon: Icons.apple_rounded,
                    title: AppTexts.t('profile.guest.upgrade_apple'),
                    onTap: isLoading ? null : onApple,
                    isPrimary: true,
                  ),
                  const SizedBox(height: 10),
                  _GuestUpgradeAction(
                    icon: Icons.g_mobiledata_rounded,
                    title: AppTexts.t('profile.guest.upgrade_google'),
                    onTap: isLoading ? null : onGoogle,
                  ),
                  const SizedBox(height: 10),
                  _GuestUpgradeAction(
                    icon: Icons.alternate_email_rounded,
                    title: AppTexts.t('profile.guest.upgrade_email'),
                    onTap: isLoading ? null : onEmail,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestUpgradeAction extends StatelessWidget {
  const _GuestUpgradeAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(colors: [_kPrimary, Color(0xFFFF00D4)])
              : null,
          color: isPrimary ? null : Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isPrimary
                ? Colors.white.withValues(alpha: 0.14)
                : _kSecondary.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isPrimary ? const Color(0xFF430036) : _kTertiary),
            const SizedBox(width: 14),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isPrimary ? const Color(0xFF430036) : _kOnSurface,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: isPrimary
                  ? const Color(0xFF430036).withValues(alpha: 0.7)
                  : _kOutlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestEmailUpgradeSheet extends StatefulWidget {
  const _GuestEmailUpgradeSheet();

  @override
  State<_GuestEmailUpgradeSheet> createState() =>
      _GuestEmailUpgradeSheetState();
}

class _GuestEmailUpgradeSheetState extends State<_GuestEmailUpgradeSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(
        color: _kOnSurface.withValues(alpha: 0.38),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: _kSecondary.withValues(alpha: 0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: _kSecondary.withValues(alpha: 0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _kPrimary, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              decoration: BoxDecoration(
                color: const Color(0xFF26112E).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _kPrimary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _kSecondary.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppTexts.t('profile.guest.email_title'),
                    style: GoogleFonts.newsreader(
                      fontSize: 28,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: _kOnSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppTexts.t('profile.guest.email_subtitle'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      height: 1.45,
                      color: _kOnSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.manrope(color: _kOnSurface),
                    decoration: _decoration('ornek@email.com'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.manrope(color: _kOnSurface),
                    decoration: _decoration(
                      AppTexts.t('profile.guest.email_password_hint'),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _kSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    style: GoogleFonts.manrope(color: _kOnSurface),
                    decoration: _decoration(
                      AppTexts.t('profile.guest.email_confirm_hint'),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _kSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(
                        _GuestEmailUpgradeInput(
                          email: _emailController.text,
                          password: _passwordController.text,
                          confirmPassword: _confirmController.text,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: const Color(0xFF430036),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: Text(
                        AppTexts.t('profile.guest.email_cta'),
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: _kTertiary, size: 22),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: _kOnSurface,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: _kSecondary.withValues(alpha: 0.58),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                trailing ??
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _kOutlineVariant,
                    ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(color: _kOutlineVariant.withValues(alpha: 0.2), height: 1),
      ],
    );
  }
}
