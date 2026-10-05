import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Helper to load and show Google AdMob Interstitial Ads.
///
/// Automatically uses Google's official sample test interstitial ad unit ID
/// in debug mode to ensure 100% fill and protect your account from invalid traffic penalties,
/// while serving your live ad unit in release builds.
class AppInterstitialAdHelper {
  // Production Interstitial Ad ID (replace with your AdMob interstitial unit ID if specific)
  static const String liveInterstitialAdUnitId = 'ca-app-pub-3831772617470767/9649646618';

  // Google's official sample test interstitial IDs
  static const String testAndroidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testIosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  static String get adUnitId {
    if (kDebugMode) {
      return Platform.isIOS ? testIosInterstitialId : testAndroidInterstitialId;
    }
    return liveInterstitialAdUnitId;
  }

  static InterstitialAd? _interstitialAd;
  static bool _isLoading = false;

  /// Pre-loads an interstitial ad into memory so it can be shown instantly when requested.
  static void loadAd() {
    if (_interstitialAd != null || _isLoading) return;

    _isLoading = true;
    try {
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isLoading = false;
            debugPrint('AppInterstitialAdHelper: Interstitial ad loaded successfully.');
          },
          onAdFailedToLoad: (error) {
            debugPrint('AppInterstitialAdHelper: Failed to load interstitial ad: ${error.message} (code: ${error.code})');
            _interstitialAd = null;
            _isLoading = false;
          },
        ),
      );
    } catch (e) {
      _isLoading = false;
      debugPrint('AppInterstitialAdHelper: Exception loading ad: $e');
    }
  }

  /// Displays the interstitial ad, then executes [onComplete] when dismissed or if unavailable.
  static void showAd({required VoidCallback onComplete}) {
    if (_interstitialAd == null) {
      debugPrint('AppInterstitialAdHelper: No interstitial ad ready. Executing callback and queuing ad load.');
      loadAd();
      onComplete();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AppInterstitialAdHelper: Ad dismissed by user.');
        ad.dispose();
        _interstitialAd = null;
        loadAd(); // Pre-load next ad for future use
        onComplete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AppInterstitialAdHelper: Failed to show ad: ${error.message}');
        ad.dispose();
        _interstitialAd = null;
        loadAd();
        onComplete();
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
  }

  /// Dispose any cached ad on app/screen tear down if needed.
  static void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isLoading = false;
  }
}
