import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dadu/component/gitf_box_banner.dart';
import 'package:dadu/component/notification_sheet.dart';
import 'package:dadu/controller/home_controller.dart';
import 'package:dadu/services/app_version_service.dart';
import 'package:dadu/services/local_notification_db.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:dadu/screen/authentication/sign_up_first.dart';
import 'package:dadu/screen/product/brand.dart';
import 'package:dadu/screen/product/catagory.dart';
import 'package:dadu/screen/product/combo_pack.dart';
import 'package:dadu/screen/product/gift_box.dart';
import 'package:dadu/screen/product/info_banner.dart';
import 'package:dadu/screen/product/product_details.dart';
import 'package:dadu/screen/product/product_item.dart';
import 'package:dadu/screen/product/search_page.dart';
import 'package:dadu/screen/user/cart.dart';
import 'package:dadu/screen/user/profile.dart';
import 'package:dadu/screen/user/reword_ad.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
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
              controller.selectedIndex.value >= 3
                  ? controller.selectedIndex.value + 1
                  : controller.selectedIndex.value,
          selectedItemColor: AppColors.selectedNavItem,
          unselectedItemColor: AppColors.unselectedNavItem,
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
              icon: Icon(Icons.search),
              label: 'Search',
            ),
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
        return const SearchPage();
      case 3:
        return controller.loggedIn.value ? const Profile() : SignUpScreen();
      default:
        return _buildHomeContent(context);
    }
  }

  Widget _buildHomeContent(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: controller.refreshData,
        child: ListView(
          controller: controller.scrollController,
          physics: const _SlowScrollPhysics(), // Applying custom slow physics
          children: [
            _buildTopBar(context),
            _buildBannerSection(context),
            _buildSectionTitle('Brand'),
            _buildBrandGrid(context),
            _buildSectionTitle('Catagory'),
            _buildCatagoryGrid(context),
            _buildComboPackBanner(context),
            _buildGiftBanner(context),
            _buildFlashSaleSection(context),
            //_buildNewArrivalSection(context),
            const _VersionUpdateBanner(),
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
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset(
              'assets/icon/user_icon.png',
              height: 35,
              fit: BoxFit.contain,
            ),
          ),
          const _TypingText(
            text: 'DADU',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 25,
              color: AppColors.textPrimary,
              fontFamily: 'Times New Roman',
            ),
          ),
          const Spacer(),

          Obx(() {
            if (!controller.loggedIn.value) return const SizedBox.shrink();
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RewordAd()),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      "Dadu coin ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      controller.coinAmount.value.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      '৳',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.coinGold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Obx(() => Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () => NotificationSheet.show(context, controller),
              ),
              if (controller.unreadNotificationCount.value > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${controller.unreadNotificationCount.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          )),
        ],
      ),
    );
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
              color: AppColors.placeholderBackground,
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
                      color: AppColors.placeholderBackground,
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
                                    color: AppColors.placeholderBackground,
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
                                    ? AppColors.textOnPrimary
                                    : AppColors.textOnPrimary.withValues(
                                      alpha: 0.5,
                                    ),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildBrandGrid(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildBrandItem(context, 'Adidas', 'assets/icon/adidas.png'),
          _buildBrandItem(context, 'Nike', 'assets/icon/Nike.png'),
          _buildBrandItem(context, 'Puma', 'assets/icon/puma.png'),
          _buildBrandItem(context, 'Dadu', 'assets/logo/black_logo.png'),
          _buildBrandItem(context, 'Mizuno', 'assets/icon/mizuno.png'),
        ],
      ),
    );
  }

  Widget _buildBrandItem(BuildContext context, String brand, String imagePath) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Brand(brandName: brand, brandLogo: imagePath),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(imagePath, fit: BoxFit.contain),
            ),
            const SizedBox(height: 6),
            Text(
              brand,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatagoryGrid(BuildContext context) {
    return Obx(() {
      return Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 3.2,
            children: [
              _buildCatagoryItem(context, 'Boots', 'assets/icon/boots.png'),
              _buildCatagoryItem(context, 'Gloves', 'assets/icon/gloves.png'),
              _buildCatagoryItem(context, 'Jersey', 'assets/icon/jersey.png'),
              _buildCatagoryItem(context, 'Pant', 'assets/icon/pant.png'),
              _buildCatagoryItem(context, 'Bag', 'assets/icon/bag.png'),
              _buildCatagoryItem(context, 'Safe Guard', 'assets/icon/safeguard.png'),
              if (controller.showAllCategories.value) ...[
                _buildCatagoryItem(context, 'Socks', 'assets/icon/socks.png'),
                _buildCatagoryItem(context, 'Others', 'assets/icon/other.png'),
              ],
            ],
          ),
          _buildMoreCategoryButton(),
        ],
      );
    });
  }

  Widget _buildMoreCategoryButton() {
    final bool isExpanded = controller.showAllCategories.value;
    return GestureDetector(
      onTap: () => controller.showAllCategories.value = !isExpanded,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isExpanded ? 'Hide' : 'More',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComboPackBanner(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ComboPack()),
        );
      },
      child: Padding(
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
                    Icon(Icons.inventory_2, color: Colors.white, size: 40),
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
      final remaining = controller.formatFlashRemaining(
        controller.flashSaleEndTime.value,
      );
      if (controller.flashProducts.isEmpty || remaining == 'Expired') {
        return const SizedBox.shrink();
      }

      final timeOnly = remaining.split(' ')[0];
      final timeParts = timeOnly.split(':');
      final h = timeParts.isNotEmpty ? timeParts[0] : '00';
      final m = timeParts.length > 1 ? timeParts[1] : '00';
      final s = timeParts.length > 2 ? timeParts[2] : '00';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.orange.shade50, Colors.orange.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'FLASH',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Icon(Icons.flash_on, color: Colors.orange, size: 28),
                  const Text(
                    'SALE',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Spacer(),
                  _buildTimerBox(h),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      ':',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  _buildTimerBox(m),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      ':',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  _buildTimerBox(s),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const _SlowScrollPhysics(),
                  itemCount: controller.flashProducts.length,
                  itemBuilder: (context, index) {
                    final product = controller.flashProducts[index];
                    return Container(
                      width: 170,
                      margin: const EdgeInsets.only(right: 12),
                      child: _FlashItem(product: product),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildShopMoreButton(context),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTimerBox(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildShopMoreButton(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: () {
          controller.scrollController.animateTo(
            controller.scrollController.offset + 400,
            duration: const Duration(milliseconds: 1200), // Slower animation
            curve: Curves.easeOutCubic,
          );
        },
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Shop More',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.orange,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_circle_right, color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildNewArrivalSection(BuildContext context) {
  //   return Obx(() {
  //     if (controller.newArrivalProducts.isEmpty) return const SizedBox.shrink();
  //
  //     return Padding(
  //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //       child: Container(
  //         padding: const EdgeInsets.all(20),
  //         decoration: BoxDecoration(
  //           color: AppColors.newArrivalBackground,
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             const Text(
  //               'New Arrivals',
  //               style: TextStyle(
  //                 fontSize: 22,
  //                 fontWeight: FontWeight.bold,
  //                 color: AppColors.textPrimary,
  //               ),
  //             ),
  //             const SizedBox(height: 10),
  //             SizedBox(
  //               height: 250,
  //               child: ListView.builder(
  //                 scrollDirection: Axis.horizontal,
  //                 itemCount: controller.newArrivalProducts.length,
  //                 itemBuilder: (context, index) {
  //                   final product = controller.newArrivalProducts[index];
  //                   return Container(
  //                     width: 180,
  //                     margin: const EdgeInsets.only(right: 10),
  //                     child: _ArrivalItem(product: product),
  //                   );
  //                 },
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     );
  //   });
  // }

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
          childAspectRatio: 0.72,
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
                  color: AppColors.textOnPrimary,
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

  Widget _buildCatagoryItem(BuildContext context, String catagory, String imagePath) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Catagory(catagoryName: catagory, catagoryLogo: imagePath),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              catagory,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Image.asset(imagePath, width: 35, height: 35, fit: BoxFit.contain),
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
}

/// Custom ScrollPhysics to decrease manual scroll speed by increasing friction
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
    // Reduce the velocity by 50% to make the scroll slower/more damped
    return super.createBallisticSimulation(position, velocity * 0.5);
  }
}

class _VersionUpdateBanner extends StatefulWidget {
  const _VersionUpdateBanner();

  @override
  State<_VersionUpdateBanner> createState() => _VersionUpdateBannerState();
}

class _VersionUpdateBannerState extends State<_VersionUpdateBanner>
    with WidgetsBindingObserver {
  bool _versionCheckLoading = true;
  bool _updateRequired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshVersionRequirement();
  }

  Future<void> _refreshVersionRequirement() async {
    final requiresUpdate = await AppVersionService.isUpdateRequired();

    if (!mounted) return;

    setState(() {
      _versionCheckLoading = false;
      _updateRequired = requiresUpdate;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    setState(() {
      _versionCheckLoading = true;
    });

    _refreshVersionRequirement();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_versionCheckLoading || !_updateRequired) {
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
              final opened = await AppVersionService.openUpdateFlow();
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open update URL')),
                );
              }
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }
}

class _TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _TypingText({required this.text, required this.style});

  @override
  State<_TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<_TypingText> {
  String _displayedText = "";
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) return;
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayedText += widget.text[_currentIndex];
          _currentIndex++;
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _displayedText = "";
              _currentIndex = 0;
            });
            _startAnimation();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedText, style: widget.style);
  }
}

class _FlashItem extends StatelessWidget {
  const _FlashItem({required this.product});

  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context) {
    final image =
        product['image5']?.toString().isNotEmpty == true
            ? product['image5'].toString()
            : product['image20']?.toString() ?? '';

    final double currentPrice =
        double.tryParse(product['price'].toString()) ?? 0;
    final double oldPrice =
        double.tryParse(product['oldPrice'].toString()) ?? 0;
    int discount = 0;
    if (oldPrice > currentPrice) {
      discount = (((oldPrice - currentPrice) / oldPrice) * 100).round();
    }

    return GestureDetector(
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
                  stock: int.tryParse(product['stock']?.toString() ?? '0') ?? 0,
                  deliveryFee: product['deliveryFee']?.toString() ?? '',
                  createdAt: product['createdAt'],
                ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: image,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder:
                        (_, __) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name']?.toString() ?? 'No Name',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '৳${product['price']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (oldPrice > 0)
                        Text(
                          '৳$oldPrice',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      const Spacer(),
                      if (discount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            '$discount%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
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
        color: AppColors.cardBackground,
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
                    catagory: product['catagory']?.toString() ?? 'Others',
                    image5: product['image5']?.toString() ?? '',
                    goldCoin: double.tryParse(product['gold_coin']?.toString() ?? '0') ?? 0.0,
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
