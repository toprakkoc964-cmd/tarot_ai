import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_ad_ids.dart';

enum AppRewardedPlacement { archiveUnlock, coinsReward }

enum AppRewardAdOutcome { earned, dismissed, unavailable }

class AppRewardAdResult {
  const AppRewardAdResult(this.outcome);

  final AppRewardAdOutcome outcome;

  bool get earned => outcome == AppRewardAdOutcome.earned;
  bool get unavailable => outcome == AppRewardAdOutcome.unavailable;
}

class AppAdService {
  AppAdService._();

  static final AppAdService instance = AppAdService._();

  static const Duration _interstitialCooldown = Duration(seconds: 90);

  bool _initialized = false;
  bool _canRequestAds = true;
  bool _loadingInterstitial = false;
  bool _loadingArchiveReward = false;
  bool _loadingCoinsReward = false;
  InterstitialAd? _pageTransitionAd;
  RewardedAd? _archiveUnlockAd;
  RewardedAd? _coinsRewardAd;
  DateTime? _lastInterstitialAt;

  bool get _adsEnabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> initialize({bool canRequestAds = true}) async {
    if (_initialized || !_adsEnabled) return;
    _initialized = true;
    _canRequestAds = canRequestAds;
    if (!_canRequestAds) {
      debugPrint('Ads initialization skipped: consent not granted.');
      return;
    }
    await MobileAds.instance.initialize();
    _loadPageTransitionInterstitial();
    _loadRewardedAd(AppRewardedPlacement.archiveUnlock);
    _loadRewardedAd(AppRewardedPlacement.coinsReward);
  }

  Future<void> maybeShowPageTransitionInterstitial() async {
    if (!_adsEnabled || !_canRequestAds) return;
    await initialize();

    final now = DateTime.now();
    final lastShown = _lastInterstitialAt;
    if (lastShown != null &&
        now.difference(lastShown) < _interstitialCooldown) {
      return;
    }

    final ad = _pageTransitionAd;
    if (ad == null) {
      _loadPageTransitionInterstitial();
      return;
    }

    final completer = Completer<void>();
    _pageTransitionAd = null;
    _lastInterstitialAt = now;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadPageTransitionInterstitial();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial show failed: $error');
        ad.dispose();
        _loadPageTransitionInterstitial();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    try {
      ad.show();
      await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {},
      );
    } catch (error) {
      debugPrint('Interstitial display error: $error');
      ad.dispose();
      _loadPageTransitionInterstitial();
    }
  }

  Future<AppRewardAdResult> showRewarded(
    AppRewardedPlacement placement, {
    required String userId,
    String? customData,
  }) async {
    if (!_adsEnabled) {
      return const AppRewardAdResult(AppRewardAdOutcome.unavailable);
    }
    if (!_canRequestAds) {
      return const AppRewardAdResult(AppRewardAdOutcome.unavailable);
    }
    await initialize();

    RewardedAd? ad = _rewardedAdFor(placement);
    if (ad == null) {
      _loadRewardedAd(placement);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      ad = _rewardedAdFor(placement);
      if (ad == null) {
        return const AppRewardAdResult(AppRewardAdOutcome.unavailable);
      }
    }

    final completer = Completer<AppRewardAdResult>();
    var earnedReward = false;
    _setRewardedAdFor(placement, null);

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd(placement);
        if (!completer.isCompleted) {
          completer.complete(
            AppRewardAdResult(
              earnedReward
                  ? AppRewardAdOutcome.earned
                  : AppRewardAdOutcome.dismissed,
            ),
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded show failed: $error');
        ad.dispose();
        _loadRewardedAd(placement);
        if (!completer.isCompleted) {
          completer.complete(
            const AppRewardAdResult(AppRewardAdOutcome.unavailable),
          );
        }
      },
    );

    try {
      if (placement == AppRewardedPlacement.coinsReward) {
        await ad.setServerSideOptions(
          ServerSideVerificationOptions(
            userId: userId,
            customData: customData ?? 'coins_progress',
          ),
        );
      }
      ad.setImmersiveMode(true);
      await ad.show(
        onUserEarnedReward: (_, __) {
          earnedReward = true;
        },
      );
    } catch (error) {
      debugPrint('Rewarded display error: $error');
      ad.dispose();
      _loadRewardedAd(placement);
      if (!completer.isCompleted) {
        completer.complete(
          const AppRewardAdResult(AppRewardAdOutcome.unavailable),
        );
      }
    }

    return completer.future;
  }

  void _loadPageTransitionInterstitial() {
    final adUnitId = AppAdIds.pageTransition;
    if (!_canRequestAds || _loadingInterstitial || adUnitId == null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _pageTransitionAd?.dispose();
          _pageTransitionAd = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          debugPrint('Interstitial load failed: $error');
        },
      ),
    );
  }

  void _loadRewardedAd(AppRewardedPlacement placement) {
    final adUnitId = switch (placement) {
      AppRewardedPlacement.archiveUnlock => AppAdIds.archiveUnlock,
      AppRewardedPlacement.coinsReward => AppAdIds.coinsReward,
    };
    if (!_canRequestAds ||
        adUnitId == null ||
        _isRewardLoadInFlight(placement)) {
      return;
    }
    _setRewardLoadInFlight(placement, true);

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _setRewardLoadInFlight(placement, false);
          _rewardedAdFor(placement)?.dispose();
          _setRewardedAdFor(placement, ad);
        },
        onAdFailedToLoad: (error) {
          _setRewardLoadInFlight(placement, false);
          debugPrint('Rewarded load failed ($placement): $error');
        },
      ),
    );
  }

  RewardedAd? _rewardedAdFor(AppRewardedPlacement placement) {
    return switch (placement) {
      AppRewardedPlacement.archiveUnlock => _archiveUnlockAd,
      AppRewardedPlacement.coinsReward => _coinsRewardAd,
    };
  }

  void _setRewardedAdFor(AppRewardedPlacement placement, RewardedAd? ad) {
    switch (placement) {
      case AppRewardedPlacement.archiveUnlock:
        _archiveUnlockAd = ad;
      case AppRewardedPlacement.coinsReward:
        _coinsRewardAd = ad;
    }
  }

  bool _isRewardLoadInFlight(AppRewardedPlacement placement) {
    return switch (placement) {
      AppRewardedPlacement.archiveUnlock => _loadingArchiveReward,
      AppRewardedPlacement.coinsReward => _loadingCoinsReward,
    };
  }

  void _setRewardLoadInFlight(AppRewardedPlacement placement, bool value) {
    switch (placement) {
      case AppRewardedPlacement.archiveUnlock:
        _loadingArchiveReward = value;
      case AppRewardedPlacement.coinsReward:
        _loadingCoinsReward = value;
    }
  }
}
