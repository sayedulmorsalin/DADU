import 'package:dadu/services/firebase.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await Future.wait([_loadFreeGiftProducts(), _checkGiftStatus()]);
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
  Widget build(BuildContext context) {
    final disableButton = _alreadyTried || _checkingGift;

    return Scaffold(
      backgroundColor: const Color(0xFFf2f2ce),
      appBar: AppBar(
        title: const Text(
          'Free Gifts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body:
          _isLoadingProducts
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
              ? const Center(
                child: Text(
                  'No free gifts available at the moment.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
              : Column(
                children: [
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
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
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
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: disableButton ? null : _handleTryGift,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              disableButton
                                  ? Colors.grey
                                  : Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
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
    );
  }
}
