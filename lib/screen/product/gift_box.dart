import 'package:dadu/services/firebase.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  /// ---------- Interstitial Ad ----------

  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();

    /// Load ad FIRST
    _loadInterstitialAd();
  }

  /// ---------- Load Ad ----------

  void _loadInterstitialAd() {

    InterstitialAd.load(
      adUnitId:
      'ca-app-pub-3940256099942544/1033173712', // TEST AD
      request: const AdRequest(),

      adLoadCallback:
      InterstitialAdLoadCallback(

        onAdLoaded: (ad) {

          _interstitialAd = ad;

          /// Show ad immediately
          _showInterstitialAd();
        },

        onAdFailedToLoad: (error) {

          debugPrint("Ad Load Failed : $error");

          /// If ad fails -> open page
          _initializePage();
        },
      ),
    );
  }

  /// ---------- Show Ad ----------

  void _showInterstitialAd() {

    if (_interstitialAd == null) {
      _initializePage();
      return;
    }

    _interstitialAd!.fullScreenContentCallback =
        FullScreenContentCallback(

          onAdDismissedFullScreenContent:
              (ad) {

            ad.dispose();

            /// AFTER AD CLOSE LOAD PAGE
            _initializePage();
          },

          onAdFailedToShowFullScreenContent:
              (ad, error) {

            ad.dispose();

            _initializePage();
          },
        );

    _interstitialAd!.show();
  }

  /// ---------- Database ----------

  Future<void> _initializePage() async {

    await Future.wait([
      _loadFreeGiftProducts(),
      _checkGiftStatus(),
    ]);
  }

  Future<void> _loadFreeGiftProducts() async {

    try {

      final productData =
      await _db.getFreeGiftProducts();

      if (!mounted) return;

      setState(() {

        _products = productData.map(

              (data) => Product(

            name:
            data['name'] ?? 'No Name',

            description:
            data['details']
                ?? 'No Description',

            imageUrl:
            data['image5'] ?? '',
          ),
        ).toList();

        _isLoadingProducts = false;
      });

    } catch (e) {

      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _checkGiftStatus() async {

    final result =
    await _db.getGiftStatus();

    if (!mounted) return;

    setState(() {

      _alreadyTried = result;

      _checkingGift = false;
    });
  }

  Future<void> _handleTryGift() async {

    setState(() {

      _checkingGift = true;
    });

    await _db.setGiftStatus(true);

    if (!mounted) return;

    setState(() {

      _alreadyTried = true;

      _checkingGift = false;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(

      const SnackBar(

        content:
        Text("Gift claimed successfully"),
      ),
    );
  }

  @override
  void dispose() {

    _interstitialAd?.dispose();

    super.dispose();
  }

  /// ---------- UI ----------

  @override
  Widget build(BuildContext context) {

    final disableButton =
        _alreadyTried || _checkingGift;

    return Scaffold(

      backgroundColor:
      const Color(0xFFf2f2ce),

      appBar: AppBar(

        title: const Text(

          'Free Gifts',

          style: TextStyle(
              fontWeight:
              FontWeight.bold),
        ),

        centerTitle: true,

        backgroundColor:
        Colors.transparent,

        elevation: 0,
      ),

      body:

      /// Loading
      _isLoadingProducts

          ? const Center(
        child:
        CircularProgressIndicator(),
      )

      /// Empty
          : _products.isEmpty

          ? const Center(

        child: Text(

          'No free gifts available at the moment.',

          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
          ),
        ),
      )

      /// Data
          : Column(

        children: [

          Expanded(

            child:
            ListView.builder(

              itemCount:
              _products.length,

              itemBuilder:
                  (context, index) {

                final product =
                _products[index];

                return Card(

                  margin:
                  const EdgeInsets
                      .symmetric(

                    horizontal: 16,
                    vertical: 8,
                  ),

                  child: Padding(

                    padding:
                    const EdgeInsets
                        .all(12),

                    child: Column(

                      children: [

                        SizedBox(

                          width: 300,
                          height: 300,

                          child:
                          Image.network(

                            product
                                .imageUrl,

                            fit:
                            BoxFit.cover,

                            errorBuilder:
                                (_, __,
                                ___) {

                              return const Icon(

                                Icons
                                    .image_not_supported,
                              );
                            },
                          ),
                        ),

                        const SizedBox(
                            height: 16),

                        Text(

                          product.name,

                          style:
                          const TextStyle(

                            fontSize: 18,

                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                            height: 8),

                        Text(
                            product
                                .description),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(

            padding:
            const EdgeInsets
                .all(24),

            child:
            SizedBox(

              width:
              double.infinity,

              child:
              ElevatedButton(

                onPressed:
                disableButton
                    ? null
                    : _handleTryGift,

                style:
                ElevatedButton
                    .styleFrom(

                  padding:
                  const EdgeInsets
                      .symmetric(

                    vertical: 16,
                  ),
                ),

                child: Text(

                  _checkingGift

                      ? "Checking..."

                      : _alreadyTried

                      ? "You already tried"

                      : "Try to Get",

                  style:
                  const TextStyle(
                      fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}