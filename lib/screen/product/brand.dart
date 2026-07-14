import 'package:dadu/screen/product/product_item.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../services/d1.dart';

class Brand extends StatefulWidget {
  final String brandName;
  final String brandLogo;

  const Brand({super.key, required this.brandName, required this.brandLogo});

  @override
  State<Brand> createState() => _BrandState();
}

class _BrandState extends State<Brand> {
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> brandProducts = [];
  bool isLoading = true;
  bool isLoadingMore = false;
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
          !isLoading) {
        fetchMoreProducts();
      }
    });
  }

  Future<void> fetchInitialProducts() async {
    setState(() {
      isLoading = true;
      currentPage = 1;
    });

    final products = await apiService.fetchProducts(
      brand: widget.brandName,
      limit: 20,
      page: currentPage,
    );
    brandProducts = products;
    if (products.isNotEmpty) currentPage++;

    setState(() => isLoading = false);
  }

  Future<void> fetchMoreProducts() async {
    setState(() => isLoadingMore = true);

    final moreProducts = await apiService.fetchProducts(
      brand: widget.brandName,
      limit: 20,
      page: currentPage,
    );

    if (moreProducts.isNotEmpty) {
      brandProducts.addAll(moreProducts);
      currentPage++;
    }

    setState(() => isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          widget.brandName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        controller: scrollController,
        physics: const _SlowScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.grey[200],
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    widget.brandLogo,
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.brandName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ))
          else if (brandProducts.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("No products found"),
            ))
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
                  productId: product['id']?.toString() ?? '',
                  title: product['name']?.toString() ?? 'No Title',
                  price: '৳${product['price']?.toString() ?? '0'}',
                  imagePath:
                      product['image5']?.toString() ?? '',
                  image20:
                      product['image20']?.toString() ?? '',
                  description: product['details']?.toString() ?? 'No details available',
                  videoLink: product['videoLink']?.toString() ?? 'No videoLink available',
                  catagory: product['catagory']?.toString() ?? 'Others',
                  image5: product['image5']?.toString() ?? '',
                  goldCoin: double.tryParse(product['gold_coin']?.toString() ?? '0') ?? 0.0,
                  brand: product['brand']?.toString() ?? '',
                  imageTwo: product['imageTwo']?.toString() ?? '',
                  imageThree: product['imageThree']?.toString() ?? '',
                  size: product['size']?.toString() ?? '',
                  stock: int.tryParse(product['stock']?.toString() ?? '0') ?? 0,
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

class _SlowScrollPhysics extends ScrollPhysics {
  const _SlowScrollPhysics({super.parent});

  @override
  _SlowScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SlowScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    return super.createBallisticSimulation(position, velocity * 0.5);
  }
}
