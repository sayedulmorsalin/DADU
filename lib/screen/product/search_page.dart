import 'package:dadu/controller/home_controller.dart';
import 'package:dadu/screen/product/product_details.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        title: const Text(
          'Search Products',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: controller.searchController,
              onChanged: controller.onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Obx(
                  () =>
                      controller.searchQuery.value.trim().isNotEmpty
                          ? IconButton(
                            onPressed: controller.clearSearch,
                            icon: const Icon(Icons.close),
                          )
                          : const SizedBox.shrink(),
                ),
                filled: true,
                fillColor: AppColors.inputFillColor,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Search for products...',
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.searchQuery.value.trim().isEmpty) {
                return _buildPlaceholder();
              }

              if (controller.isSearching.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.searchResults.isEmpty) {
                return const Center(
                  child: Text(
                    'No products found',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.searchResults.length,
                itemBuilder: (context, index) {
                  final product = controller.searchResults[index];

                  return _buildSearchResultItem(context, product);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_rounded,
            size: 80,
            color: AppColors.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Search for your favorite products',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(BuildContext context, Map<String, dynamic> product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => ProductDetails(
                    productid: product['id']?.toString() ?? '',
                    title: product['name']?.toString() ?? '',
                    price: product['price']?.toString() ?? '0',
                    image20: product['image20']?.toString() ?? '',
                    description: product['details']?.toString() ?? '',
                    videoLink: product['videoLink']?.toString() ?? '',
                    catagory: product['catagory']?.toString() ?? 'Others',
                    image5: product['image5']?.toString() ?? '',
                    goldCoin: double.tryParse(product['gold_coin']?.toString() ?? '0') ?? 0.0,
                    brand: product['brand']?.toString() ?? '',
                    imageTwo: product['imageTwo']?.toString() ?? '',
                    imageThree: product['imageThree']?.toString() ?? '',
                    size: product['size']?.toString() ?? '',
                    stock: int.tryParse(product['stock']?.toString() ?? '1') ?? 1,
                    deliveryFee: product['deliveryFee']?.toString() ?? '',
                    createdAt: product['createdAt'],
                  ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  product['image20'] ?? '',
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    width: 70,
                    height: 70,
                    color: AppColors.surfaceGrey,
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '৳${product['price']}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (product['catagory'] != null)
                      Text(
                        product['catagory'],
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
