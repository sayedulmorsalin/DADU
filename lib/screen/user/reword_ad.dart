import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../services/firebase.dart';

class RewordAd extends StatefulWidget {
  const RewordAd({super.key});

  @override
  State<RewordAd> createState() => _RewordAdState();
}

class _RewordAdState extends State<RewordAd> {

  /// ---------- Coins ----------

  double silverCoins = 0;
  double goldCoins = 0;

  final dataBase db = dataBase();

  /// ---------- Ad Rules ----------

  int adsWatchedToday = 0;
  int adsInRow = 0;

  DateTime? cooldownEnd;
  DateTime today = DateTime.now();

  Timer? _countdownTimer;

  bool get isCooldownActive =>
      cooldownEnd != null &&
          DateTime.now().isBefore(cooldownEnd!);

  String cooldownText() {

    if (!isCooldownActive) return "";

    final diff =
    cooldownEnd!.difference(DateTime.now());

    final minutes =
    diff.inMinutes.remainder(60)
        .toString()
        .padLeft(2, "0");

    final seconds =
    diff.inSeconds.remainder(60)
        .toString()
        .padLeft(2, "0");

    return "Next ads available in : $minutes:$seconds";
  }

  Future<void> loadCoins() async {

    final data =
    await db.getUserCoins();

    if(data == null) return;

    setState(() {

      silverCoins =
          (data["silver_coin"] ?? 0)
              .toDouble();

      goldCoins =
          (data["free_delivery_info"] ?? 0)
              .toDouble();
    });
  }

  void startCountdownTimer() {

    _countdownTimer?.cancel();

    _countdownTimer =
        Timer.periodic(
            const Duration(seconds: 1),
                (timer) {

              if (!mounted) return;

              if (!isCooldownActive) {

                timer.cancel();

                setState(() {});
                return;
              }

              setState(() {});
            });
  }

  /// ---------- Banner ----------

  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  void loadBannerAd() {

    _bannerAd = BannerAd(

      size: AdSize.banner,

      adUnitId:
      'ca-app-pub-3940256099942544/6300978111',

      request: const AdRequest(),

      listener: BannerAdListener(

        onAdLoaded: (ad) {

          if (!mounted) return;

          setState(() {
            _isBannerReady = true;
          });
        },

        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    _bannerAd!.load();
  }

  /// ---------- Rewarded ----------

  RewardedAd? _rewardedAd;

  void loadRewardedAd() {

    RewardedAd.load(

      adUnitId:
      'ca-app-pub-3940256099942544/5224354917',

      request: const AdRequest(),

      rewardedAdLoadCallback:

      RewardedAdLoadCallback(

        onAdLoaded: (ad) {

          _rewardedAd = ad;

          ad.fullScreenContentCallback =

              FullScreenContentCallback(

                onAdDismissedFullScreenContent: (ad) {

                  ad.dispose();
                  loadRewardedAd();
                },

                onAdFailedToShowFullScreenContent:
                    (ad, error) {

                  ad.dispose();
                  loadRewardedAd();
                },
              );
        },

        onAdFailedToLoad: (error) {},
      ),
    );
  }

  void _resetDailyIfNeeded() {

    final now = DateTime.now();

    if (now.day != today.day ||
        now.month != today.month ||
        now.year != today.year) {

      adsWatchedToday = 0;
      adsInRow = 0;
      cooldownEnd = null;

      today = now;
    }
  }

  void showRewardedAd() {

    _resetDailyIfNeeded();

    if (adsWatchedToday >= 50) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text("Daily limit reached"),
        ),
      );

      return;
    }

    if (isCooldownActive) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text("Cooldown active"),
        ),
      );

      return;
    }

    if (adsInRow >= 5) {

      cooldownEnd =
          DateTime.now()
              .add(const Duration(minutes: 30));

      adsInRow = 0;

      startCountdownTimer();

      setState(() {});

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text("Cooldown Started 30 minutes"),
        ),
      );

      return;
    }

    if (_rewardedAd == null) {

      loadRewardedAd();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text("Ad loading..."),
        ),
      );

      return;
    }

    _rewardedAd!.show(

      onUserEarnedReward:
          (AdWithoutView ad,
          RewardItem reward) async {

        setState(() {

          silverCoins += 5;

          adsInRow++;
          adsWatchedToday++;
        });

        await db.updateSilverCoin(
            silverCoins);

        ScaffoldMessenger.of(context)
            .showSnackBar(

          const SnackBar(
            content:
            Text("+5 Silver Coins"),
          ),
        );
      },
    );

    _rewardedAd = null;
  }

  /// ---------- Convert Coins ----------

  void convertCoins() async {

    if (silverCoins <= 0) {

      ScaffoldMessenger.of(context)
          .showSnackBar(

        const SnackBar(
          content:
          Text("No Silver Coins to convert"),
        ),
      );

      return;
    }

    setState(() {

      goldCoins +=
          silverCoins / 100;

      silverCoins = 0;
    });

    /// Firebase Update

    await db.updateGoldCoin(
        goldCoins);

    await db.updateSilverCoin(
        silverCoins);

    ScaffoldMessenger.of(context)
        .showSnackBar(

      const SnackBar(
        content:
        Text("Coins Converted Successfully"),
      ),
    );
  }

  /// ---------- Init ----------

  @override
  void initState(){

    super.initState();

    loadCoins();

    loadBannerAd();

    loadRewardedAd();
  }

  /// ---------- Dispose ----------

  @override
  void dispose() {

    _countdownTimer?.cancel();

    _bannerAd?.dispose();

    _rewardedAd?.dispose();

    super.dispose();
  }

  /// ---------- Coin Card ----------

  Widget coinCard(
      String title,
      double value,
      IconData icon,
      Color color) {

    return Expanded(

      child: Card(

        child: Padding(

          padding:
          const EdgeInsets.all(15),

          child: Column(

            children: [

              Icon(icon,
                  size: 40,
                  color: color),

              Text(title),

              Text(

                value.toStringAsFixed(2),

                style:
                const TextStyle(
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ---------- UI ----------

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar:
      AppBar(
        title:
        const Text("Earn Coins"),
      ),

      body: Column(

        children: [

          Expanded(

            child: Padding(

              padding:
              const EdgeInsets.all(20),

              child: Column(

                children: [

                  Row(

                    children: [

                      coinCard(
                        "Silver",
                        silverCoins,
                        Icons.monetization_on,
                        Colors.grey,
                      ),

                      const SizedBox(width: 10),

                      coinCard(
                        "Gold",
                        goldCoins,
                        Icons.workspace_premium,
                        Colors.amber,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  ElevatedButton.icon(

                    onPressed:
                    isCooldownActive
                        ? null
                        : showRewardedAd,

                    icon:
                    const Icon(Icons.play_arrow),

                    label:
                    const Text("Watch Ad"),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(

                    onPressed:
                    convertCoins,

                    child:
                    const Text(
                        "Convert Silver → Gold"),
                  ),

                  const SizedBox(height: 20),

                  Text(
                      "Daily Ads : $adsWatchedToday / 50"),

                  Text(
                      "Row Ads : $adsInRow / 5"),
                ],
              ),
            ),
          ),

          if (_isBannerReady)

            SizedBox(

              width:
              _bannerAd!.size.width
                  .toDouble(),

              height:
              _bannerAd!.size.height
                  .toDouble(),

              child:
              AdWidget(
                  ad:
                  _bannerAd!),
            ),
        ],
      ),
    );
  }
}