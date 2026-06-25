import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/screen/product/product_item.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';

import '../../services/firebase.dart';

class ComboPack extends StatefulWidget {
  const ComboPack({super.key});

  @override
  State<ComboPack> createState() => _ComboPackState();
}

class _ComboPackState extends State<ComboPack> {
  String bundle = "Combo Pack";
  final dataBase db = new dataBase();
  List<Map<String, dynamic>> brandProducts = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  DocumentSnapshot? lastDocument;
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchInitialProducts();

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          !isLoading) {
        fetchMoreProducts();
      }
    });
  }

  Future<void> fetchInitialProducts() async {
    final products = await db.getBrandedProduct(bundle);
    brandProducts = products;

    if (products.isNotEmpty) {
      lastDocument = products.last['docSnapshot'];
    }

    setState(() => isLoading = false);
  }

  Future<void> fetchMoreProducts() async {
    if (lastDocument == null) return;

    setState(() => isLoadingMore = true);
    final moreProducts = await db.getBrandedProduct(
      bundle,
      startAfterDoc: lastDocument,
    );

    if (moreProducts.isNotEmpty) {
      lastDocument = moreProducts.last['docSnapshot'];
      brandProducts.addAll(moreProducts);
    }

    setState(() => isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          bundle,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        controller: scrollController,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6D00), Color(0xFFFFAB40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Icon(
                      Icons.shopping_bag,
                      size: 100,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          color: Colors.white,
                          size: 40,
                        ),
                        SizedBox(width: 20),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COMBO PACK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              'Save more with our bundles!',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (brandProducts.isEmpty)
            const Center(child: Text("No products found"))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: brandProducts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final product = brandProducts[index];
                return ProductItem(
                  productId: product['id'],
                  title: product['name'] ?? 'No Title',
                  price: '৳${product['price']?.toString() ?? '0'}',
                  imagePath:
                      product['image5'] ?? 'assets/demo_item_image/d1.jpg',
                  image20:
                      product['image20'] ?? 'assets/demo_item_image/d1.jpg',
                  description: product['details'] ?? 'No details available',
                  videoLink: product['videoLink'] ?? 'No videoLink available',
                  brand: product['brand'] ?? 'no brand found ',
                  image5: product['image5'] ?? 'assets/demo_item_image/d1.jpg',
                  goldCoin: (product['gold_coin'] as num?)?.toDouble() ?? 0.0,
                );
              },
            ),

          if (isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
