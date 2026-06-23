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
                        'Type to search for products',
                        style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (controller.searchResults.isEmpty &&
                  controller.isSearchReady.value) {
                return const Center(child: Text('No products found'));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.searchResults.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final productName = controller.searchResults[index];

                  return ListTile(
                    leading: const Icon(Icons.history, size: 20),
                    title: Text(productName),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      final product = await controller.getProductByName(
                        productName,
                      );
                      if (!context.mounted) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ProductDetails(
                                productid: product['id'] as String,
                                title: product['name']?.toString() ?? '',
                                price: product['price']?.toString() ?? '0',
                                image20: product['image20']?.toString() ?? '',
                                description:
                                    product['details']?.toString() ?? '',
                                videoLink:
                                    product['videoLink']?.toString() ?? '',
                                brand: product['brand']?.toString() ?? 'Others',
                                image5: product['image5']?.toString() ?? '',
                              ),
                        ),
                      );
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
