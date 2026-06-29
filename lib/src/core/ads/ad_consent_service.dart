import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConsentService {
  Future<bool> gatherConsentAndTracking() async {
    try {
      await _requestConsentInfoUpdate();
      await _loadAndShowConsentFormIfRequired();
      await _requestTrackingIfNeeded();
      return await ConsentInformation.instance.canRequestAds();
    } catch (error, stackTrace) {
      debugPrint('Ad consent flow failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _fallbackCanRequestAds();
    }
  }

  Future<void> _requestConsentInfoUpdate() {
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      (FormError error) {
        debugPrint(
          'Consent info update failed: ${error.errorCode} ${error.message}',
        );
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    return completer.future;
  }

  Future<void> _loadAndShowConsentFormIfRequired() {
    return ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (error != null) {
        debugPrint(
          'Consent form dismissed with error: '
          '${error.errorCode} ${error.message}',
        );
      }
    });
  }

  Future<void> _requestTrackingIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (error, stackTrace) {
      debugPrint('ATT request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> _fallbackCanRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (error) {
      debugPrint('Consent fallback failed: $error');
      return true;
    }
  }
}
