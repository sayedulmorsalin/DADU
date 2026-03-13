import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/firebase.dart';

class RewordAd extends StatefulWidget {
  const RewordAd({super.key});

  @override
  State<RewordAd> createState() => _RewordAdState();
}

class _RewordAdState extends State<RewordAd> {
  final dataBase db = dataBase();

  double silverCoins = 0;
  double goldCoins = 0;
  double silverRewardRate = 5;

  int adsWatchedToday = 0;
  int adsInRow = 0;

  DateTime? cooldownEnd;
  DateTime today = DateTime.now();

  Timer? _countdownTimer;

  bool get isCooldownActive =>
      cooldownEnd != null && DateTime.now().isBefore(cooldownEnd!);

  bool get isDailyLimitReached => adsWatchedToday >= 50;

  int get adsLeftBeforeCooldown => (10 - adsInRow).clamp(0, 10);

  Future<void> loadUserData() async {
    final coinData = await db.getUserCoins();
    silverRewardRate = await db.getRewardAdSilverRate();

    if (coinData != null) {
      silverCoins = (coinData["silver_coin"] ?? 0).toDouble();

      goldCoins = (coinData["free_delivery_info"] ?? 0).toDouble();
    }

    final info = await db.getRewardAdInfo();

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
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3831772617470767/5972409454',

      request: const AdRequest(),

      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();

              loadRewardedAd();
            },

            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();

              loadRewardedAd();
            },
          );
        },

        onAdFailedToLoad: (error) {},
      ),
    );
  }

  void showRewardedAd() {
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

    if (adsInRow >= 10) {
      cooldownEnd = DateTime.now().add(const Duration(minutes: 30));

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
        await db.increaseGlobalMonthlyRewardAdCount();

        await db.updateSilverCoin(silverCoins);

        await saveRewardInfo();

        if (mounted) setState(() {});
      },
    );

    _rewardedAd = null;
  }

  void convertCoins() async {
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
    _bannerAd = BannerAd(
      size: AdSize.banner,

      adUnitId: 'ca-app-pub-3831772617470767/9497704030',

      request: const AdRequest(),

      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;

          setState(() {
            _bannerReady = true;
          });
        },

        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    _bannerAd!.load();
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

    loadUserData();

    loadRewardedAd();

    loadBannerAd();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();

    _rewardedAd?.dispose();

    _bannerAd?.dispose();

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

      body: Column(
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
                        style: TextStyle(color: AppColors.textOnPrimary),
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
                          Text("Daily Ads $adsWatchedToday / 50"),

                          LinearProgressIndicator(
                            value: (adsWatchedToday / 50).clamp(0.0, 1.0),
                          ),

                          const SizedBox(height: 12),

                          Text("Continuous Ads $adsInRow / 10"),

                          LinearProgressIndicator(
                            value: (adsInRow / 10).clamp(0.0, 1.0),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            "$adsLeftBeforeCooldown ads left before cooldown",

                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),

                          if (isCooldownActive)
                            Padding(
                              padding: const EdgeInsets.only(top: 15),

                              child: Container(
                                padding: const EdgeInsets.all(10),

                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),

                                  borderRadius: BorderRadius.circular(12),
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

          if (_bannerReady)
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
