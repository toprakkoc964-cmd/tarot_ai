import 'package:flutter/foundation.dart';

class AppAdIds {
  const AppAdIds._();

  static const String iosAppId = 'ca-app-pub-1049995727707465~8176094796';

  static String? get banner => _iosOnly(
    sample: 'ca-app-pub-3940256099942544/2934735716',
    live: 'ca-app-pub-1049995727707465/6032255565',
  );

  static String? get pageTransition => _iosOnly(
    sample: 'ca-app-pub-3940256099942544/4411468910',
    live: 'ca-app-pub-1049995727707465/3322331741',
  );

  static String? get archiveUnlock => _iosOnly(
    sample: 'ca-app-pub-3940256099942544/1712485313',
    live: 'ca-app-pub-1049995727707465/6383609356',
  );

  static String? get coinsReward => _iosOnly(
    sample: 'ca-app-pub-3940256099942544/1712485313',
    live: 'ca-app-pub-1049995727707465/3861387799',
  );

  static String? _iosOnly({required String sample, required String live}) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    const useLiveAdsInDebug = bool.fromEnvironment(
      'USE_LIVE_ADS',
      defaultValue: false,
    );
    if (kDebugMode && !useLiveAdsInDebug) {
      return sample;
    }
    return live;
  }
}
