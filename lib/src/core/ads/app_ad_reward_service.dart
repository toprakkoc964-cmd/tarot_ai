import 'package:shared_preferences/shared_preferences.dart';

import '../tarot_functions_client.dart';

class DailyLoginRewardResult {
  const DailyLoginRewardResult({
    required this.granted,
    required this.grantedCredits,
    required this.remainingCredits,
    required this.claimDay,
  });

  final bool granted;
  final int grantedCredits;
  final int remainingCredits;
  final String? claimDay;
}

class CoinsRewardProgressResult {
  const CoinsRewardProgressResult({
    required this.progress,
    required this.stepsRemaining,
    required this.grantedCredits,
    required this.remainingCredits,
  });

  final int progress;
  final int stepsRemaining;
  final int grantedCredits;
  final int remainingCredits;
}

class AppAdRewardService {
  AppAdRewardService._();

  static final AppAdRewardService instance = AppAdRewardService._();

  static const _archiveUnlockDuration = Duration(hours: 24);
  final TarotFunctionsClient _functionsClient = TarotFunctionsClient();

  String _archiveUnlockKey(String uid) => 'archive_unlock_until_ms_$uid';

  Future<DailyLoginRewardResult> claimDailyLoginReward() async {
    final response = await _functionsClient.claimDailyLoginReward();
    return DailyLoginRewardResult(
      granted: response['granted'] == true,
      grantedCredits: (response['grantedCredits'] as num?)?.toInt() ?? 0,
      remainingCredits: (response['remainingCredits'] as num?)?.toInt() ?? 0,
      claimDay: response['claimDay']?.toString(),
    );
  }

  Future<CoinsRewardProgressResult> claimCoinsRewardProgress() async {
    final response = await _functionsClient.claimAdWatchReward(
      rewardType: 'coins_progress',
    );
    return CoinsRewardProgressResult(
      progress: (response['progress'] as num?)?.toInt() ?? 0,
      stepsRemaining: (response['stepsRemaining'] as num?)?.toInt() ?? 3,
      grantedCredits: (response['grantedCredits'] as num?)?.toInt() ?? 0,
      remainingCredits: (response['remainingCredits'] as num?)?.toInt() ?? 0,
    );
  }

  Future<DateTime?> loadArchiveUnlockUntil(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_archiveUnlockKey(uid));
    if (millis == null || millis <= 0) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(millis);
    if (!until.isAfter(DateTime.now())) {
      await prefs.remove(_archiveUnlockKey(uid));
      return null;
    }
    return until;
  }

  Future<DateTime> unlockArchiveFor24Hours(String uid) async {
    final until = DateTime.now().add(_archiveUnlockDuration);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_archiveUnlockKey(uid), until.millisecondsSinceEpoch);
    return until;
  }

  bool isArchiveUnlocked(DateTime? unlockUntil) {
    if (unlockUntil == null) return false;
    return unlockUntil.isAfter(DateTime.now());
  }

  bool isSameLocalDay(DateTime? instant, {DateTime? now}) {
    if (instant == null) return false;
    final current = now ?? DateTime.now();
    return instant.year == current.year &&
        instant.month == current.month &&
        instant.day == current.day;
  }
}
