import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Reusable banner ad widget for displaying Google AdMob banner ads at the bottom of the screen.
/// Implements [PreferredSizeWidget] and strictly constrains its height to the ad height (50dp),
/// preventing any vertical expansion or touch blocking on the rest of the screen.
///
/// Automatically uses Google's official test ad unit ID in debug mode to guarantee
/// 100% fill rate and protect your AdMob account from invalid traffic penalties,
/// while serving your live ad unit ID in production/release mode.
class AppBannerAdWidget extends StatefulWidget implements PreferredSizeWidget {
  final String? adUnitId;
  final AdSize adSize;
  final Color? backgroundColor;

  // Live AdMob Banner ID for production
  static const String liveBannerAdUnitId = 'ca-app-pub-3831772617470767/2220866700';

  // Google's official sample test ad unit IDs
  static const String testAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testIosBannerId = 'ca-app-pub-3940256099942544/2934735716';

  const AppBannerAdWidget({
    super.key,
    this.adUnitId,
    this.adSize = AdSize.banner,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => Size.fromHeight(adSize.height.toDouble());

  @override
  State<AppBannerAdWidget> createState() => _AppBannerAdWidgetState();
}

class _AppBannerAdWidgetState extends State<AppBannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  String get _effectiveAdUnitId {
    if (widget.adUnitId != null && widget.adUnitId!.isNotEmpty) {
      return widget.adUnitId!;
    }
    if (kDebugMode) {
      return Platform.isIOS
          ? AppBannerAdWidget.testIosBannerId
          : AppBannerAdWidget.testAndroidBannerId;
    }
    return AppBannerAdWidget.liveBannerAdUnitId;
  }

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    try {
      final unitId = _effectiveAdUnitId;
      debugPrint('AppBannerAdWidget: Loading banner with unit ID: $unitId (debugMode=$kDebugMode)');

      _bannerAd = BannerAd(
        size: widget.adSize,
        adUnitId: unitId,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() {
              _isLoaded = true;
            });
            debugPrint('AppBannerAdWidget: Banner ad loaded successfully.');
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('AppBannerAdWidget failed to load: ${error.message} (code: ${error.code})');
            ad.dispose();
            if (mounted) {
              setState(() {
                _isLoaded = false;
                _bannerAd = null;
              });
            }
          },
        ),
      );

      _bannerAd!.load();
    } catch (e) {
      debugPrint('AppBannerAdWidget exception during load: $e');
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final double adWidth = _bannerAd!.size.width.toDouble();
    final double adHeight = _bannerAd!.size.height.toDouble();

    return SafeArea(
      top: false,
      child: SizedBox(
        height: adHeight,
        width: double.infinity,
        child: ColoredBox(
          color: widget.backgroundColor ?? Colors.white,
          child: Center(
            child: SizedBox(
              width: adWidth,
              height: adHeight,
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
        ),
      ),
    );
  }
}
