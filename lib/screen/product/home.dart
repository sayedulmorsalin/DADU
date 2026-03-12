import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/component/gitf_box_banner.dart';
import 'package:dadu/controller/home_controller.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:dadu/screen/authentication/sign_up_first.dart';
import 'package:dadu/screen/product/brands.dart';
import 'package:dadu/screen/product/bundle_deals.dart';
import 'package:dadu/screen/product/gift_box.dart';
import 'package:dadu/screen/product/info_banner.dart';
import 'package:dadu/screen/product/product_details.dart';
import 'package:dadu/screen/product/product_item.dart';
import 'package:dadu/screen/user/cart.dart';
import 'package:dadu/screen/user/profile.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class Home extends StatelessWidget {
  Home({super.key});

  final HomeController controller = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Obx(() => _buildCurrentPage(context)),
      bottomNavigationBar: Obx(
        () => BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex:
              controller.selectedIndex.value >= 2
                  ? controller.selectedIndex.value + 1
                  : controller.selectedIndex.value,
          selectedItemColor: AppColors.selectedNavItem,
          unselectedItemColor: Colors.black54,
          onTap:
              (index) => controller.onBottomNavTap(
                index,
                onMessageTap: _sendMessageToWhatsApp,
              ),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(icon: _buildCartNavIcon(), label: 'Cart'),
            const BottomNavigationBarItem(
              icon: Icon(Icons.message),
              label: 'Message',
            ),
            BottomNavigationBarItem(
              icon: _buildProfileNavIcon(),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPage(BuildContext context) {
    switch (controller.selectedIndex.value) {
      case 0:
        return _buildHomeContent(context);
      case 1:
        return controller.loggedIn.value ? const Cart() : SignUpScreen();
      case 2:
        return controller.loggedIn.value ? const Profile() : SignUpScreen();
      default:
        return _buildHomeContent(context);
    }
  }

  Widget _buildHomeContent(BuildContext context) {
    return SafeArea(
      child: ListView(
        controller: controller.scrollController,
        children: [
          _buildTopBar(context),
          _buildSearchResults(context),
          _buildBannerSection(context),
          _buildBrandGrid(context),
          _buildBundleBanner(context),
          _buildGiftBanner(context),
          _buildFlashSaleSection(context),
          _buildNewArrivalSection(context),
          _buildVersionUpdateBanner(context),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: InfoBanner(),
          ),
          _buildProductGrid(),
          Obx(
            () =>
                controller.isLoadingMore.value
                    ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                    : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Text(
              'DADU',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 25,
                color: Colors.black,
                fontFamily: 'Times New Roman',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: controller.searchController,
                onChanged: controller.onSearchChanged,
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
                  isDense: true,
                  fillColor: AppColors.inputFillColor,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Search products',
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => _showNotificationDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    return Obx(() {
      if (!controller.showSearchResults.value) {
        return const SizedBox(height: 8);
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: controller.searchResults.length,
          itemBuilder: (context, index) {
            final productName = controller.searchResults[index];

            return ListTile(
              title: Text(productName),
              onTap: () async {
                final product = await controller.getProductByName(productName);
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
                          description: product['details']?.toString() ?? '',
                          videoLink: product['videoLink']?.toString() ?? '',
                          brand: product['brand']?.toString() ?? 'Others',
                          image5: product['image5']?.toString() ?? '',
                        ),
                  ),
                );
              },
            );
          },
        ),
      );
    });
  }

  Widget _buildBannerSection(BuildContext context) {
    return Obx(() {
      final banners = controller.banners;

      if (banners.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.width / 2.16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[300],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/icon/banner.jpg', fit: BoxFit.cover),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SizedBox(
          height: MediaQuery.of(context).size.width / 2.16,
          child: Stack(
            children: [
              PageView.builder(
                controller: controller.bannerPageController,
                itemCount: banners.length,
                onPageChanged: controller.onBannerChanged,
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  final imageUrl = banner['imageUrl']?.toString();

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[300],
                    ),
                    child:
                        imageUrl == null || imageUrl.isEmpty
                            ? Image.asset(
                              'assets/icon/banner.jpg',
                              fit: BoxFit.cover,
                            )
                            : CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder:
                                  (_, __) => Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (_, __, ___) => Image.asset(
                                    'assets/icon/banner.jpg',
                                    fit: BoxFit.cover,
                                  ),
                            ),
                  );
                },
              ),
              if (banners.length > 1)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Obx(
                    () => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        banners.length,
                        (index) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                controller.currentBannerIndex.value == index
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBrandGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      children: [
        _buildBrandItem(context, 'Adidas', 'assets/icon/adidas.png'),
        _buildBrandItem(context, 'Nike', 'assets/icon/Nike.png'),
        _buildBrandItem(context, 'Puma', 'assets/icon/puma.png'),
        _buildBrandItem(context, 'Gloves', 'assets/icon/gloves.png'),
        _buildBrandItem(context, 'Jersey', 'assets/icon/jersey.png'),
        _buildBrandItem(context, 'Pant', 'assets/icon/pant.png'),
        _buildBrandItem(context, 'Dadu', 'assets/logo/black_logo.png'),
        _buildBrandItem(context, 'Others', 'assets/icon/other.png'),
      ],
    );
  }

  Widget _buildBundleBanner(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BundleDeals()),
        );
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Image(
          image: AssetImage('assets/gif/bundle.gif'),
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildGiftBanner(BuildContext context) {
    return Obx(
      () => AnimatedSlide(
        offset:
            controller.giftBannerVisible.value
                ? Offset.zero
                : const Offset(0, 0.2),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: controller.giftBannerVisible.value ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 350),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GiftBoxBanner(
              onOpen: () {
                if (!controller.loggedIn.value) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SignUpScreen()),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GiftBox()),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlashSaleSection(BuildContext context) {
    return Obx(() {
      if (controller.flashProducts.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.flashSaleBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Flash Sale',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 265,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: controller.flashProducts.length,
                  itemBuilder: (context, index) {
                    final product = controller.flashProducts[index];
                    return Container(
                      width: 180,
                      margin: const EdgeInsets.only(right: 10),
                      child: _FlashItem(
                        product: product,
                        remaining: controller.formatFlashRemaining(
                          product['flash-expire'],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildNewArrivalSection(BuildContext context) {
    return Obx(() {
      if (controller.newArrivalProducts.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Arrivals',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: controller.newArrivalProducts.length,
                  itemBuilder: (context, index) {
                    final product = controller.newArrivalProducts[index];
                    return Container(
                      width: 180,
                      margin: const EdgeInsets.only(right: 10),
                      child: _ArrivalItem(product: product),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildVersionUpdateBanner(BuildContext context) {
    return StreamBuilder<String?>(
      stream: controller.db.getVersionStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final version = int.tryParse(snapshot.data!);
        if (version == null || version <= 1) {
          return const SizedBox.shrink();
        }

        return Container(
          color: AppColors.updateBanner,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.update),
                  SizedBox(width: 8),
                  Text('New update is available!'),
                ],
              ),
              TextButton(
                onPressed: () async {
                  const url = 'https://appnest-seven.vercel.app/';
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open update URL'),
                      ),
                    );
                  }
                },
                child: const Text('UPDATE'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductGrid() {
    return Obx(() {
      if (controller.isInitialLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (controller.products.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Center(child: Text('No products found')),
        );
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.products.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.79,
        ),
        itemBuilder: (context, index) {
          final product = controller.products[index];

          return ProductItem(
            productId: product['id']?.toString() ?? '',
            title: product['name']?.toString() ?? 'No Title',
            price: '৳${product['price']?.toString() ?? '0'}',
            imagePath: product['image5']?.toString() ?? '',
            image20: product['image20']?.toString() ?? '',
            description:
                product['details']?.toString() ?? 'No details available',
            videoLink:
                product['videoLink']?.toString() ?? 'No videoLink available',
            brand: product['brand']?.toString() ?? 'Others',
            image5: product['image5']?.toString() ?? '',
          );
        },
      );
    });
  }

  Widget _buildProfileNavIcon() {
    if (controller.profileImageLoading.value) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final imageUrl = controller.profileImageUrl.value;
    if (controller.loggedIn.value && imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundImage: CachedNetworkImageProvider(imageUrl),
      );
    }

    return const Icon(Icons.person);
  }

  Widget _buildCartNavIcon() {
    final totalItems = controller.cartCount.value;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.shopping_cart),
        if (totalItems > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.badgeBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                totalItems > 99 ? '99+' : totalItems.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBrandItem(BuildContext context, String brand, String imagePath) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Brands(brandName: brand, brandLogo: imagePath),
          ),
        );
      },
      child: SizedBox(
        width: 100,
        height: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 50, height: 50, fit: BoxFit.contain),
            const SizedBox(height: 5),
            Text(
              brand,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessageToWhatsApp() async {
    final message = Uri.encodeComponent(
      'Hey I want to order something from your Apps',
    );

    final appUri = Uri.parse(
      'whatsapp://send?phone=8801782124891&text=$message',
    );
    final webUri = Uri.parse('https://wa.me/8801782124891?text=$message');

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
      return;
    }

    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  void _showNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.notifications, color: Colors.orange),
              SizedBox(width: 8),
              Text('Notifications'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('notifications')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No notifications yet'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final ts = data['createdAt'] as Timestamp?;
                    final time =
                        ts != null
                            ? TimeOfDay.fromDateTime(
                              ts.toDate(),
                            ).format(context)
                            : '';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          data['highPriority'] == true
                              ? Icons.priority_high
                              : Icons.notifications,
                          color:
                              data['highPriority'] == true
                                  ? Colors.red
                                  : Colors.blue,
                        ),
                        title: Text(
                          data['title']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(data['body']?.toString() ?? ''),
                        trailing: Text(
                          time,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _FlashItem extends StatelessWidget {
  const _FlashItem({required this.product, required this.remaining});

  final Map<String, dynamic> product;
  final String remaining;

  @override
  Widget build(BuildContext context) {
    final image =
        product['image5']?.toString().isNotEmpty == true
            ? product['image5'].toString()
            : product['image20']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: GestureDetector(
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
                    brand: product['brand']?.toString() ?? 'Others',
                    image5: product['image5']?.toString() ?? '',
                  ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:
                      image.isEmpty
                          ? Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported),
                          )
                          : CachedNetworkImage(
                            imageUrl: image,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder:
                                (_, __) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            errorWidget:
                                (_, __, ___) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                ),
                          ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product['name']?.toString() ?? 'No Name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                remaining == 'Expired' ? 'Expired' : '⏳ $remaining',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color:
                      remaining == 'Expired'
                          ? AppColors.error
                          : AppColors.success,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Price: ৳${product['price']?.toString() ?? '0'}',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.selectedNavItem,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrivalItem extends StatelessWidget {
  const _ArrivalItem({required this.product});

  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context) {
    final image =
        product['image5']?.toString().isNotEmpty == true
            ? product['image5'].toString()
            : product['image20']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: GestureDetector(
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
                    brand: product['brand']?.toString() ?? 'Others',
                    image5: product['image5']?.toString() ?? '',
                  ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:
                      image.isEmpty
                          ? Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported),
                          )
                          : CachedNetworkImage(
                            imageUrl: image,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder:
                                (_, __) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            errorWidget:
                                (_, __, ___) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                ),
                          ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product['name']?.toString() ?? 'No Name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Price: ৳${product['price']?.toString() ?? '0'}',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.selectedNavItem,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
