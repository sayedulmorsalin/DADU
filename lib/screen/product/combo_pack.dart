import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/screen/product/product_item.dart';
import 'package:flutter/material.dart';

import '../../services/firebase.dart';
import '../../services/d1.dart';

class ComboPack extends StatefulWidget {
  const ComboPack({super.key});

  @override
  State<ComboPack> createState() => _ComboPackState();
}

class _ComboPackState extends State<ComboPack> {
  String bundle = "Combo Pack";
  final dataBase db = dataBase();
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> catagoryProducts = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  int currentPage = 1;
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchInitialProducts();

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          !isLoading &&
          hasMore) {
        fetchMoreProducts();
      }
    });
  }

  Future<void> fetchInitialProducts() async {
    currentPage = 1;
    hasMore = true;
    final products = await apiService.fetchProducts(
      category: bundle,
      limit: 20,
      page: currentPage,
    );
    catagoryProducts = products;
    if (products.length < 20) {
      hasMore = false;
    } else {
      currentPage++;
    }

    setState(() => isLoading = false);
  }

  Future<void> fetchMoreProducts() async {
    if (isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);
    final moreProducts = await apiService.fetchProducts(
      category: bundle,
      limit: 20,
      page: currentPage,
    );

    if (moreProducts.isEmpty || moreProducts.length < 20) {
      hasMore = false;
    }
    if (moreProducts.isNotEmpty) {
      catagoryProducts.addAll(moreProducts);
      currentPage++;
    }

    setState(() => isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          bundle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
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
                    color: Colors.orange.withValues(alpha: 0.3),
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
                      color: Colors.white.withValues(alpha: 0.15),
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
          else if (catagoryProducts.isEmpty)
            const Center(child: Text("No products found"))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: catagoryProducts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final product = catagoryProducts[index];
                return ProductItem(
                  productId: product['id'] ?? '',
                  title: product['name'] ?? 'No Title',
                  price: '৳${product['price']?.toString() ?? '0'}',
                  imagePath:
                      product['image5'] ?? 'assets/demo_item_image/d1.jpg',
                  image20:
                      product['image20'] ?? 'assets/demo_item_image/d1.jpg',
                  description: product['details'] ?? 'No details available',
                  videoLink: product['videoLink'] ?? 'No videoLink available',
                  catagory: product['catagory'] ?? 'no catagory found',
                  image5: product['image5'] ?? 'assets/demo_item_image/d1.jpg',
                  goldCoin: double.tryParse(product['gold_coin']?.toString() ?? '0') ?? 0.0,
                  brand: product['brand']?.toString() ?? '',
                  imageTwo: product['imageTwo']?.toString() ?? '',
                  imageThree: product['imageThree']?.toString() ?? '',
                  size: product['size']?.toString() ?? '',
                  stock: int.tryParse(product['stock']?.toString() ?? '1') ?? 1,
                  deliveryFee: product['deliveryFee']?.toString() ?? '',
                  createdAt: product['createdAt'],
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
