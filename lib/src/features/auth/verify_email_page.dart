import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';
import '../../core/localization_service.dart';
import '../../core/theme/app_colors.dart';
import 'auth_service.dart';
import 'user_profile_contract.dart';
import 'widgets/mystic_primary_button.dart';
import 'widgets/mystic_toast.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({
    super.key,
    required this.authService,
    required this.user,
    required this.onVerified,
    required this.onChangeEmail,
  });

  final AuthService authService;
  final User user;
  final VoidCallback onVerified;
  final VoidCallback onChangeEmail;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  Timer? _cooldownTimer;
  Timer? _verificationTimer;
  int _cooldownSeconds = AuthService.verificationResendCooldownSeconds;
  bool _checking = false;
  bool _pollingCheckInFlight = false;
  bool _resending = false;
  bool _dailyLimitReached = false;
  bool _hasAutoNavigated = false;
  DateTime? _lastManualCheckAt;

  @override
  void initState() {
    super.initState();
    _ensurePendingVerificationDoc();
    _startCooldown(_cooldownSeconds);
    _startVerificationPolling();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _verificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _ensurePendingVerificationDoc() async {
    try {
      final user = FirebaseAuth.instance.currentUser ?? widget.user;
      final userRef = FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(user.uid);
      final snap = await userRef.get();
      final data = snap.data() ?? const <String, dynamic>{};
      final hasDeadline =
          data[UserProfileContract.verificationDeadlineAt] != null;
      await userRef.set({
        UserProfileContract.uid: user.uid,
        if ((user.email ?? '').trim().isNotEmpty)
          UserProfileContract.email: user.email!.trim(),
        UserProfileContract.provider: 'password',
        UserProfileContract.providers: const ['password'],
        UserProfileContract.emailVerified: user.emailVerified,
        UserProfileContract.providerVerified: false,
        UserProfileContract.isProfileComplete: false,
        UserProfileContract.onboardingCompleted: false,
        UserProfileContract.accountStatus:
            UserProfileContract.statusPendingEmailVerification,
        UserProfileContract.cleanupEligible: true,
        if (!hasDeadline)
          UserProfileContract.verificationDeadlineAt: Timestamp.fromDate(
            DateTime.now().add(
              const Duration(hours: AuthService.verificationTtlHours),
            ),
          ),
        if (!snap.exists)
          UserProfileContract.createdAt: FieldValue.serverTimestamp(),
        UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // The visible screen still works; cleanup metadata can be repaired later.
    }
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds.clamp(0, 9999));
    if (_cooldownSeconds <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
        return;
      }
      setState(() => _cooldownSeconds -= 1);
    });
  }

  void _startVerificationPolling() {
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollVerification());
    });
    unawaited(_pollVerification());
  }

  Future<void> _pollVerification() async {
    if (_hasAutoNavigated || _checking || _resending || _pollingCheckInFlight) {
      return;
    }
    _pollingCheckInFlight = true;
    try {
      final verified = await widget.authService.reloadAndCheckEmailVerified();
      if (!mounted || !verified) return;
      await _handleVerifiedAndNavigate(showToast: true);
    } catch (_) {
      // Auto polling stays silent; the manual button reports visible errors.
    } finally {
      _pollingCheckInFlight = false;
    }
  }

  Future<void> _handleVerifiedAndNavigate({required bool showToast}) async {
    if (_hasAutoNavigated) return;
    _hasAutoNavigated = true;
    _verificationTimer?.cancel();
    _cooldownTimer?.cancel();
    await widget.authService.markCurrentUserEmailVerified();
    if (!mounted) return;
    if (showToast) {
      MysticToast.showSuccess(
        context,
        AppTexts.t('verifyEmailVerifiedSuccess'),
        dedupeKey: 'verify_email_success',
      );
    }
    widget.onVerified();
  }

  Future<void> _checkVerification() async {
    if (_checking || _resending) return;
    final now = DateTime.now();
    final lastManualCheckAt = _lastManualCheckAt;
    if (lastManualCheckAt != null &&
        now.difference(lastManualCheckAt) < const Duration(seconds: 3)) {
      MysticToast.showInfo(
        context,
        AppTexts.t('verifyEmailManualCooldown'),
        dedupeKey: 'verify_email_manual_cooldown',
      );
      return;
    }
    _lastManualCheckAt = now;
    setState(() => _checking = true);
    try {
      final verified = await widget.authService.reloadAndCheckEmailVerified();
      if (!mounted) return;
      if (!verified) {
        MysticToast.showInfo(
          context,
          AppTexts.t('verifyEmailNotVerifiedYet'),
          dedupeKey: 'verify_email_not_verified',
        );
        return;
      }
      await _handleVerifiedAndNavigate(showToast: true);
    } catch (_) {
      if (!mounted) return;
      MysticToast.showError(
        context,
        AppTexts.t('verifyEmailNetworkError'),
        dedupeKey: 'verify_email_check_error',
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_resending ||
        _checking ||
        _hasAutoNavigated ||
        _cooldownSeconds > 0 ||
        _dailyLimitReached) {
      return;
    }
    setState(() => _resending = true);
    try {
      await widget.authService.resendVerificationEmail();
      if (!mounted) return;
      _dailyLimitReached = false;
      _startCooldown(AuthService.verificationResendCooldownSeconds);
      MysticToast.showSuccess(
        context,
        AppTexts.t('verifyEmailResendSuccess'),
        dedupeKey: 'verify_email_resend_success',
      );
    } on VerificationResendLimitException catch (error) {
      if (!mounted) return;
      if (error.code == 'cooldown') {
        _startCooldown(error.remainingSeconds);
        return;
      }
      setState(() => _dailyLimitReached = true);
      MysticToast.showWarning(
        context,
        AppTexts.t('verifyEmailDailyLimitInline'),
        dedupeKey: 'verify_email_daily_limit',
      );
    } catch (_) {
      if (!mounted) return;
      MysticToast.showError(
        context,
        AppTexts.t('verifyEmailResendError'),
        dedupeKey: 'verify_email_resend_error',
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _signOut() async {
    await widget.authService.signOut();
  }

  Future<void> _changeEmail() async {
    await widget.authService.signOut();
    if (!mounted) return;
    widget.onChangeEmail();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LocalizationService.instance.revision,
      builder: (context, _, __) {
        final email =
            widget.user.email ?? AppTexts.t('verifyEmailUnknownEmail');
        final cooldownText = AppTexts.t(
          'verifyEmailCooldownInline',
        ).replaceAll('{seconds}', '$_cooldownSeconds');

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              const _VerifyEmailBackground(),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 36),
                      _buildHero(),
                      const SizedBox(height: 28),
                      _InlineStatusCard(
                        icon: Icons.mail_outline_rounded,
                        title: AppTexts.t('verifyEmailSentTo'),
                        body: email,
                        accent: AppColors.tertiaryGold,
                      ),
                      const SizedBox(height: 14),
                      _InlineStatusCard(
                        icon: Icons.info_outline_rounded,
                        title: AppTexts.t('verifyEmailCheckSpamTitle'),
                        body: AppTexts.t('verifyEmailCheckSpamDescription'),
                        accent: AppColors.secondaryLavender,
                      ),
                      const SizedBox(height: 14),
                      _InlineStatusCard(
                        icon: Icons.shield_outlined,
                        title: AppTexts.t('verifyEmailSecurityTitle'),
                        body: AppTexts.t('verifyEmailSecurityDescription'),
                        accent: AppColors.primaryPink,
                      ),
                      const SizedBox(height: 14),
                      _InlineStatusCard(
                        icon: Icons.autorenew_rounded,
                        title: AppTexts.t('verifyEmailWaitingTitle'),
                        body: AppTexts.t('verifyEmailWaitingDescription'),
                        accent: AppColors.secondaryLavender,
                      ),
                      const SizedBox(height: 24),
                      MysticPrimaryButton(
                        label: _checking
                            ? AppTexts.t('verifyEmailChecking')
                            : AppTexts.t('verifyEmailCheckedButton'),
                        loading: _checking,
                        onPressed: _checking ? null : _checkVerification,
                      ),
                      const SizedBox(height: 12),
                      _SecondaryActionButton(
                        icon: Icons.refresh_rounded,
                        label: _resending
                            ? AppTexts.t('verifyEmailResending')
                            : AppTexts.t('verifyEmailResendButton'),
                        onPressed:
                            _resending ||
                                _checking ||
                                _cooldownSeconds > 0 ||
                                _dailyLimitReached
                            ? null
                            : _resend,
                      ),
                      if (_cooldownSeconds > 0 || _dailyLimitReached) ...[
                        const SizedBox(height: 10),
                        Text(
                          _dailyLimitReached
                              ? AppTexts.t('verifyEmailDailyLimitInline')
                              : cooldownText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: _dailyLimitReached
                                ? AppColors.tertiaryGold
                                : AppColors.secondaryLavender,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _TextAction(
                              label: AppTexts.t('verifyEmailChangeEmail'),
                              onPressed: _changeEmail,
                            ),
                          ),
                          Expanded(
                            child: _TextAction(
                              label: AppTexts.t('verifyEmailSignOut'),
                              onPressed: _signOut,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        AppTexts.t('verifyEmailDeadlineInfo'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.secondaryLavender.withValues(
                            alpha: 0.72,
                          ),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppTexts.t('auth.register.guide'),
          style: GoogleFonts.inter(
            color: AppColors.secondaryLavender,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        IconButton(
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded),
          color: AppColors.primaryPink,
          tooltip: AppTexts.t('verifyEmailSignOut'),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.glassBg,
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryNeonPink.withValues(alpha: 0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Icon(
              Icons.mark_email_unread_outlined,
              color: AppColors.tertiaryGold,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppTexts.t('verifyEmailTitle'),
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            color: AppColors.primaryPink,
            fontSize: 38,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppTexts.t('verifyEmailSubtitle'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontSize: 16,
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppTexts.t('verifyEmailDescription'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.secondaryLavender,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _InlineStatusCard extends StatelessWidget {
  const _InlineStatusCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        body,
                        style: GoogleFonts.inter(
                          color: AppColors.onSurface,
                          fontSize: 13,
                          height: 1.45,
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

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondaryLavender,
          side: BorderSide(
            color: AppColors.secondaryLavender.withValues(alpha: 0.35),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: AppColors.primaryPink,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _VerifyEmailBackground extends StatelessWidget {
  const _VerifyEmailBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.1,
          colors: [AppColors.cosmicGradientTop, AppColors.background],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}
