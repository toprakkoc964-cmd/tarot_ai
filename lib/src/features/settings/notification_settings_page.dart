import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';
import '../auth/user_profile_contract.dart';

const _kBg = Color(0xFF17081C);
const _kPrimary = Color(0xFFFF5ED6);
const _kTertiary = Color(0xFFFFE792);
const _kOnSurface = Color(0xFFFADCFF);
const _kCard = Color(0xFF26112E);

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key, required this.uid});

  final String uid;

  DocumentReference<Map<String, dynamic>> get _userRef => FirebaseFirestore
      .instance
      .collection(UserProfileContract.usersCollection)
      .doc(uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _kOnSurface),
        title: Text(
          AppTexts.t('notificationSettingsTitle'),
          style: GoogleFonts.spaceGrotesk(
            color: _kOnSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userRef.snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final prefs =
              data[UserProfileContract.notificationPrefs] as Map? ??
              const <String, dynamic>{};
          final enabled = prefs['enabled'] as bool? ?? true;
          final dailyCard = prefs['dailyCard'] as Map? ?? const {};
          final dailyCardEnabled = dailyCard['enabled'] as bool? ?? true;
          final dailyHour = (dailyCard['hourLocal'] as num?)?.toInt() ?? 9;
          final followups =
              prefs['coffeePalmFollowup'] as Map? ?? const <String, dynamic>{};
          final walletOffers =
              prefs['walletOffers'] as Map? ?? const <String, dynamic>{};

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _SettingsTile(
                title: AppTexts.t('notificationSettingsGeneral'),
                value: enabled,
                onChanged: (value) => _set('notificationPrefs.enabled', value),
              ),
              _SettingsTile(
                title: AppTexts.t('notificationSettingsDailyCard'),
                value: dailyCardEnabled,
                enabled: enabled,
                onChanged: (value) =>
                    _set('notificationPrefs.dailyCard.enabled', value),
              ),
              _TimeTile(
                hour: dailyHour,
                enabled: enabled && dailyCardEnabled,
                onTap: () => _pickHour(context, dailyHour),
              ),
              _SettingsTile(
                title: AppTexts.t('notificationSettingsCoffeePalm'),
                value: followups['enabled'] as bool? ?? true,
                enabled: enabled,
                onChanged: (value) =>
                    _set('notificationPrefs.coffeePalmFollowup.enabled', value),
              ),
              _SettingsTile(
                title: AppTexts.t('notificationSettingsWalletOffers'),
                value: walletOffers['enabled'] as bool? ?? true,
                enabled: enabled,
                onChanged: (value) =>
                    _set('notificationPrefs.walletOffers.enabled', value),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _set(String fieldPath, Object value) async {
    await _userRef.update({
      fieldPath: value,
      UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> _pickHour(BuildContext context, int currentHour) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: _kCard,
      builder: (context) {
        var selectedHour = currentHour;
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    AppTexts.t('notificationSettingsTime'),
                    style: GoogleFonts.spaceGrotesk(
                      color: _kOnSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 42,
                    scrollController: FixedExtentScrollController(
                      initialItem: currentHour.clamp(0, 23),
                    ),
                    onSelectedItemChanged: (value) => selectedHour = value,
                    children: List.generate(
                      24,
                      (hour) => Center(
                        child: Text(
                          '${hour.toString().padLeft(2, '0')}:00',
                          style: const TextStyle(color: _kOnSurface),
                        ),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, selectedHour),
                  child: Text(AppTexts.t('common.save_profile')),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null) {
      await _set('notificationPrefs.dailyCard.hourLocal', picked);
    }
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      enabled: enabled,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.manrope(
                color: _kOnSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: _kPrimary,
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.hour,
    required this.enabled,
    required this.onTap,
  });

  final int hour;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppTexts.t('notificationSettingsTime'),
              style: GoogleFonts.manrope(
                color: _kOnSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${hour.toString().padLeft(2, '0')}:00',
            style: GoogleFonts.spaceGrotesk(
              color: _kTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.enabled = true, this.onTap});

  final Widget child;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kCard.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kPrimary.withValues(alpha: 0.24)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
