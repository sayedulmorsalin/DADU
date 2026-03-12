import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/services/firebase.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Product {
  final String name;
  final String description;
  final String imageUrl;

  const Product({
    required this.name,
    required this.description,
    required this.imageUrl,
  });
}

class GiftBox extends StatefulWidget {
  const GiftBox({super.key});

  @override
  State<GiftBox> createState() => _GiftBoxState();
}

class _GiftBoxState extends State<GiftBox> {
  final dataBase _db = dataBase();

  List<Product> _products = [];
  bool _isLoadingProducts = true;
  bool _checkingGift = true;
  bool _alreadyTried = false;

  String? _lastWinnerName;
  String? _lastWinnerLocation;
  String? _lastWinnerTime;
  bool _isCurrentUserWinner = false;
  bool _loadingWinner = true;

  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-3831772617470767/9497704030',
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isBannerReady = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _bannerAd!.load();
  }

  InterstitialAd? _interstitialAd;

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3831772617470767/8328092598',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _showInterstitialAd();
        },
        onAdFailedToLoad: (error) {
          _initializePage();
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd == null) {
      _initializePage();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _initializePage();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _initializePage();
      },
    );

    _interstitialAd!.show();
  }

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadInterstitialAd();
  }

  Future<void> _initializePage() async {
    await Future.wait([
      _loadFreeGiftProducts(),
      _checkGiftStatus(),
      _loadLastWinner(),
    ]);
  }

  Future<void> _loadFreeGiftProducts() async {
    try {
      final productData = await _db.getFreeGiftProducts();

      if (!mounted) return;

      setState(() {
        _products =
            productData
                .map(
                  (data) => Product(
                    name: data['name'] ?? 'No Name',
                    description: data['details'] ?? 'No Description',
                    imageUrl: data['image5'] ?? '',
                  ),
                )
                .toList();

        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _checkGiftStatus() async {
    final result = await _db.getGiftStatus();

    if (!mounted) return;

    setState(() {
      _alreadyTried = result;
      _checkingGift = false;
    });
  }

  Future<void> _loadLastWinner() async {
    try {
      final winner = await _db.getLastGiftWinner();

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      String? formattedTime;

      if (winner?['time'] != null) {
        final timeData = winner!['time'];

        if (timeData is Timestamp) {
          final dateTime = timeData.toDate();

          formattedTime =
              "${dateTime.day}/${dateTime.month}/${dateTime.year} "
              "${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
        } else if (timeData is String) {
          formattedTime = timeData;
        }
      }

      if (!mounted) return;

      setState(() {
        _lastWinnerName = winner?['name'];
        _lastWinnerLocation = winner?['location'];
        _lastWinnerTime = formattedTime;

        _isCurrentUserWinner =
            currentUserId != null && winner?['user_id'] == currentUserId;

        _loadingWinner = false;
      });
    } catch (e) {
      _loadingWinner = false;
    }
  }

  Future<void> _handleTryGift() async {
    setState(() => _checkingGift = true);

    await _db.setGiftStatus(true);

    if (!mounted) return;

    setState(() {
      _alreadyTried = true;
      _checkingGift = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Gift claimed successfully")));
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableButton = _alreadyTried || _checkingGift;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Free Gifts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoadingProducts
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                      children: [
                        if (!_loadingWinner && _lastWinnerName != null)
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.emoji_events,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isCurrentUserWinner
                                        ? "🎉 You are the Winner!"
                                        : "🎉 Last Winner : $_lastWinnerName from $_lastWinnerLocation • $_lastWinnerTime",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        width: 300,
                                        height: 300,
                                        child: Image.network(
                                          product.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, __, ___) => const Icon(
                                                Icons.image_not_supported,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(product.description),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: disableButton ? null : _handleTryGift,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                _checkingGift
                                    ? "Checking..."
                                    : _alreadyTried
                                    ? "You already tried"
                                    : "Try to Get",
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
          if (_isBannerReady)
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
