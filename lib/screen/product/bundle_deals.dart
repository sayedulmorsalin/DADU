import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/screen/product/product_item.dart';
import 'package:flutter/material.dart';

import '../../services/firebase.dart';
class BundleDeals extends StatefulWidget {
  const BundleDeals({super.key});

  @override
  State<BundleDeals> createState() => _BundleDealsState();
}

class _BundleDealsState extends State<BundleDeals> {
  String bundle = "Bundle";
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
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200 &&
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
  final moreProducts = await db.getBrandedProduct(bundle, startAfterDoc: lastDocument);

  if (moreProducts.isNotEmpty) {
    lastDocument = moreProducts.last['docSnapshot'];
    brandProducts.addAll(moreProducts);
  }

  setState(() => isLoadingMore = false);
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    //backgroundColor: const Color(0xFFf2f2ce),
    appBar: AppBar(
      title: Text(bundle, style: TextStyle(fontWeight: FontWeight.bold,fontSize: 30),),
      backgroundColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
    ),
    body: ListView(
      controller: scrollController,
      children: [

        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.grey[200],
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  "assets/gif/bundle.gif",
                  height: 80,
                  fit: BoxFit.contain,
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
              childAspectRatio: 0.70,
            ),
            itemBuilder: (context, index) {
              final product = brandProducts[index];
              return ProductItem(
                productId: product['id'],
                title: product['name'] ?? 'No Title',
                price: '৳${product['price']?.toString() ?? '0'}',
                imagePath: product['image5'] ?? 'assets/demo_item_image/d1.jpg',
                image20: product['image20'] ?? 'assets/demo_item_image/d1.jpg',
                description: product['details'] ?? 'No details available',
                videoLink:
                product['videoLink'] ?? 'No videoLink available',
                brand: product['brand']?? 'no brand found ',
                image5: product['image5']??'assets/demo_item_image/d1.jpg',
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
