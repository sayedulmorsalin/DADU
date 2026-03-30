import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/services/app_version_service.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firebase.dart';

const String _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.sayedulmarsalin.dadu';

class RewordAd extends StatefulWidget {
  const RewordAd({super.key});

  @override
  State<RewordAd> createState() => _RewordAdState();
}

class _RewordAdState extends State<RewordAd> with WidgetsBindingObserver {
  static const int _dailyAdLimit = 30;
  static const int _adsPerRowLimit = 3;
  static const Duration _cooldownDuration = Duration(minutes: 30);

  final dataBase db = dataBase();

  double silverCoins = 0;
  double goldCoins = 0;
  double silverRewardRate = 5;

  int adsWatchedToday = 0;
  int adsInRow = 0;

  DateTime? cooldownEnd;
  DateTime today = DateTime.now();

  Timer? _countdownTimer;
  StreamSubscription<String?>? _versionSubscription;
  bool _versionCheckLoading = true;
  bool _updateRequired = false;
  bool _rewardAccessInitialized = false;
  String? _remoteVersion;

  bool get isCooldownActive =>
      cooldownEnd != null && DateTime.now().isBefore(cooldownEnd!);

  bool get isDailyLimitReached => adsWatchedToday >= _dailyAdLimit;

  int get adsLeftBeforeCooldown =>
      (_adsPerRowLimit - adsInRow).clamp(0, _adsPerRowLimit);

  Future<void> loadUserData() async {
    if (_versionCheckLoading || _updateRequired) return;

    final coinData = await db.getUserCoins();
    final rewardRate = await db.getRewardAdSilverRate();

    if (!mounted || _updateRequired) return;

    silverRewardRate = rewardRate;

    if (coinData != null) {
      silverCoins = (coinData["silver_coin"] ?? 0).toDouble();

      goldCoins = (coinData["free_delivery_info"] ?? 0).toDouble();
    }

    final info = await db.getRewardAdInfo();

    if (!mounted || _updateRequired) return;

    if (info != null) {
      adsWatchedToday = info["ads_today"] ?? 0;

      adsInRow = info["ads_in_row"] ?? 0;

      if (info["cooldown_end"] is Timestamp) {
        cooldownEnd = (info["cooldown_end"] as Timestamp).toDate();
      }

      if (info["last_watch_day"] is Timestamp) {
        today = (info["last_watch_day"] as Timestamp).toDate();
      }
    }

    _resetDailyIfNeeded();

    if (_updateRequired) return;

    if (mounted) setState(() {});

    startCountdownTimer();
  }

  Future<void> saveRewardInfo() async {
    await db.updateRewardAdInfo({
      "ads_today": adsWatchedToday,
      "ads_in_row": adsInRow,
      "cooldown_end": cooldownEnd,
      "last_watch_day": today,
    });
  }

  void _resetDailyIfNeeded() {
    final now = DateTime.now();

    if (now.year != today.year ||
        now.month != today.month ||
        now.day != today.day) {
      adsWatchedToday = 0;

      adsInRow = 0;

      cooldownEnd = null;

      today = now;

      saveRewardInfo();
    }
  }

  void startCountdownTimer() {
    _countdownTimer?.cancel();

    if (_versionCheckLoading || _updateRequired || !isCooldownActive) {
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (!isCooldownActive) {
        _countdownTimer?.cancel();
      }

      setState(() {});
    });
  }

  String cooldownText() {
    if (!isCooldownActive) return "";

    final diff = cooldownEnd!.difference(DateTime.now());

    final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, "0");

    final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, "0");

    return "$minutes:$seconds";
  }

  RewardedAd? _rewardedAd;

  void loadRewardedAd() {
    if (_versionCheckLoading || _updateRequired) return;

    RewardedAd.load(
      adUnitId: 'ca-app-pub-3831772617470767/9649646618',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted || _updateRequired) {
            ad.dispose();
            return;
          }

          _rewardedAd = ad;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();

              if (!mounted || _updateRequired) return;

              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();

              if (!mounted || _updateRequired) return;

              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          if (!mounted || _updateRequired) return;

          print("Rewarded failed: ${error.code} ${error.message}");

          // Retry loading after a delay
          Future.delayed(const Duration(seconds: 5), () {
            if (!mounted || _updateRequired) return;

            loadRewardedAd();
          });
        },
      ),
    );
  }

  void showRewardedAd() {
    if (_versionCheckLoading || _updateRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please update your app first")),
      );

      return;
    }

    _resetDailyIfNeeded();

    if (isDailyLimitReached) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Daily limit reached")));

      return;
    }

    if (isCooldownActive) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cooldownText())));

      return;
    }

    if (adsInRow >= _adsPerRowLimit) {
      cooldownEnd = DateTime.now().add(_cooldownDuration);

      adsInRow = 0;

      saveRewardInfo();

      startCountdownTimer();

      setState(() {});

      return;
    }

    if (_rewardedAd == null) {
      loadRewardedAd();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ad loading")));

      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        silverCoins += silverRewardRate;

        adsInRow++;

        adsWatchedToday++;

        if (adsInRow >= _adsPerRowLimit) {
          cooldownEnd = DateTime.now().add(_cooldownDuration);
          adsInRow = 0;
          startCountdownTimer();
        }

        await db.increaseGlobalMonthlyRewardAdCount();

        await db.updateSilverCoin(silverCoins);

        await saveRewardInfo();

        if (mounted) setState(() {});
      },
    );

    _rewardedAd = null;
  }

  void convertCoins() async {
    if (_versionCheckLoading || _updateRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please update your app first")),
      );

      return;
    }

    if (silverCoins <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No Silver Coins")));

      return;
    }

    final convertedGold = silverCoins / 100;

    goldCoins += convertedGold;

    silverCoins = 0;

    await db.updateGoldCoin(goldCoins);

    await db.updateSilverCoin(silverCoins);

    if (mounted) setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Converted +${convertedGold.toStringAsFixed(2)} Gold"),
      ),
    );
  }

  BannerAd? _bannerAd;

  bool _bannerReady = false;

  void loadBannerAd() {
    if (_versionCheckLoading || _updateRequired) return;

    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-3831772617470767/2220866700',
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || _updateRequired) {
            ad.dispose();
            return;
          }

          setState(() {
            _bannerReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print("Banner failed: ${error.code} ${error.message}");
          ad.dispose();
        },
      ),
    );

    _bannerAd!.load();
  }

  void _disposeRewardAds() {
    _countdownTimer?.cancel();
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _bannerReady = false;
  }

  void _initializeRewardAccess() {
    if (_rewardAccessInitialized) return;

    _rewardAccessInitialized = true;
    loadUserData();
    loadRewardedAd();
    loadBannerAd();
  }

  Future<void> _refreshVersionRequirement([String? remoteVersion]) async {
    final currentRemoteVersion = remoteVersion ?? _remoteVersion;
    final requiresUpdate =
        currentRemoteVersion != null &&
        await AppVersionService.isUpdateRequired(currentRemoteVersion);

    if (!mounted || currentRemoteVersion != _remoteVersion) return;

    if (requiresUpdate) {
      _disposeRewardAds();
    }

    setState(() {
      _updateRequired = requiresUpdate;
      _versionCheckLoading = false;

      if (requiresUpdate) {
        _rewardAccessInitialized = false;
      }
    });

    if (!requiresUpdate) {
      _initializeRewardAccess();
    }
  }

  void _listenForVersionUpdates() {
    _versionSubscription = db.getVersionStream().listen(
      (remoteVersion) {
        _remoteVersion = remoteVersion;
        unawaited(_refreshVersionRequirement(remoteVersion));
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          _remoteVersion = null;
          _updateRequired = false;
          _versionCheckLoading = false;
        });

        _initializeRewardAccess();
      },
    );
  }

  Future<void> _openUpdatePage() async {
    final uri = Uri.parse(_playStoreUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open update URL")),
      );
    }
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildUpdateRequiredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update, size: 54, color: AppColors.warning),
                const SizedBox(height: 16),
                const Text(
                  "Update required",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Please update the app to access reward ads and earn coins.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _openUpdatePage,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("Update App"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rewardPrimary,
                    foregroundColor: AppColors.textOnPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget coinCard(String title, double value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, size: 42, color: color),
              const SizedBox(height: 8),
              Text(title),
              Text(
                value.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForVersionUpdates();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _remoteVersion == null) return;

    setState(() {
      _versionCheckLoading = true;
    });

    unawaited(_refreshVersionRequirement());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _versionSubscription?.cancel();
    _disposeRewardAds();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableButton = isCooldownActive || isDailyLimitReached;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Earn Coins",
          style: TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.rewardPrimary,
      ),
      body:
          _versionCheckLoading
              ? _buildLoadingState()
              : _updateRequired
              ? _buildUpdateRequiredState()
              : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              coinCard(
                                "Silver",
                                silverCoins,
                                Icons.monetization_on,
                                AppColors.coinSilver,
                              ),
                              IconButton(
                                iconSize: 45,
                                onPressed: convertCoins,
                                icon: const Icon(Icons.swap_horiz),
                              ),
                              coinCard(
                                "Gold",
                                goldCoins,
                                Icons.workspace_premium,
                                AppColors.coinGold,
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton.icon(
                              onPressed: disableButton ? null : showRewardedAd,
                              icon: const Icon(
                                Icons.play_arrow,
                                color: AppColors.textOnPrimary,
                              ),
                              label: const Text(
                                "Watch Ad",
                                style: TextStyle(
                                  color: AppColors.textOnPrimary,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    disableButton
                                        ? AppColors.disabledColor
                                        : AppColors.rewardPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Per ad reward: +${silverRewardRate.toStringAsFixed(2)} Silver",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 25),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                children: [
                                  Text(
                                    "Daily Ads $adsWatchedToday / $_dailyAdLimit",
                                  ),
                                  LinearProgressIndicator(
                                    value: (adsWatchedToday / _dailyAdLimit)
                                        .clamp(0.0, 1.0),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Continuous Ads $adsInRow / $_adsPerRowLimit",
                                  ),
                                  LinearProgressIndicator(
                                    value: (adsInRow / _adsPerRowLimit).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "$adsLeftBeforeCooldown ads left before cooldown",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isCooldownActive)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 15),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          "Next ads in : ${cooldownText()}",
                                          style: const TextStyle(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_bannerReady && _bannerAd != null)
                    SizedBox(
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    ),
                ],
              ),
    );
  }
}
