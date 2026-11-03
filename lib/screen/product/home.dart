import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dadu/component/home_skeleton.dart';
import 'package:dadu/component/notification_sheet.dart';
import 'package:dadu/controller/home_controller.dart';
import 'package:dadu/services/app_version_service.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:dadu/screen/authentication/sign_up_first.dart';
import 'package:dadu/screen/product/brand.dart';
import 'package:dadu/screen/product/catagory.dart';
import 'package:dadu/screen/product/combo_pack.dart';
import 'package:dadu/screen/product/info_banner.dart';
import 'package:dadu/screen/product/product_details.dart';
import 'package:dadu/screen/product/product_item.dart';
import 'package:dadu/screen/product/search_page.dart';
import 'package:dadu/screen/product/buy_old_boot.dart';
import 'package:dadu/screen/product/sell_old_product.dart';
import 'package:dadu/screen/user/cart.dart';
import 'package:dadu/screen/user/chat.dart';
import 'package:dadu/screen/user/profile.dart';
import 'package:dadu/screen/user/reword_ad.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class Home extends StatelessWidget {
  Home({super.key});

  final HomeController controller = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: controller.selectedIndex.value == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          controller.selectedIndex.value = 0;
        },
        child: Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: _buildCurrentPage(context),
          floatingActionButton: controller.selectedIndex.value == 0
              ? _buildCustomerServiceFab(context)
              : null,
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: controller.selectedIndex.value,
            selectedItemColor: AppColors.selectedNavItem,
            unselectedItemColor: AppColors.unselectedNavItem,
            onTap: (index) => controller.onBottomNavTap(index),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(icon: Obx(() => _buildCartNavIcon()), label: 'Cart'),
              const BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Obx(() => _buildMessageNavIcon()),
                label: 'Message',
              ),
              BottomNavigationBarItem(
                icon: Obx(() => _buildProfileNavIcon()),
                label: 'Profile',
              ),
            ],
          ),
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
        return controller.loggedIn.value ? const Chat() : SignUpScreen();
      case 4:
        return controller.loggedIn.value ? const Profile() : SignUpScreen();
      default:
        return _buildHomeContent(context);
    }
  }

  Widget _buildHomeContent(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: controller.refreshData,
        child: CustomScrollView(
          controller: controller.scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: SmoothGlideScrollPhysics(),
          ),
          cacheExtent: 1200,
          slivers: [
            SliverToBoxAdapter(child: RepaintBoundary(child: _buildTopBar(context))),
            SliverToBoxAdapter(child: RepaintBoundary(child: _buildBannerSection(context))),
            SliverToBoxAdapter(child: RepaintBoundary(child: _buildOldBootButtons(context))),
            SliverToBoxAdapter(child: _buildSectionTitle('Brand')),
            SliverToBoxAdapter(child: RepaintBoundary(child: _buildBrandGrid(context))),
            SliverToBoxAdapter(child: _buildSectionTitle('Catagory')),
            SliverToBoxAdapter(child: RepaintBoundary(child: _buildCatagoryGrid(context))),
            SliverToBoxAdapter(child: RepaintBoundary(child: _buildComboPackBanner(context))),
            SliverToBoxAdapter(child: RepaintBoundary(child: _buildFlashSaleSection(context))),
            const SliverToBoxAdapter(child: _VersionUpdateBanner()),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: InfoBanner(),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSectionTitle('Recommended For You'),
            ),
            _ProductSliverGrid(controller: controller),
            _LoadMoreSliver(controller: controller),
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
                    const Text(
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
        return const BannerSkeleton();
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
                              memCacheWidth: 800,
                              placeholder:
                                  (_, __) => const ShimmerWidget(
                                    child: SkeletonContainer(
                                      width: double.infinity,
                                      height: double.infinity,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(12),
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

  Widget _buildOldBootButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: _AnimatedOldBootCard(
              title: 'Buy Old Boot',
              subtitle: 'Pre-owned gear',
              badgeText: 'VERIFIED',
              icon: Icons.shopping_bag_rounded,
              gradientColors: const [
                Color(0xFF1E3A8A), // Deep Royal Navy
                Color(0xFF2563EB), // Electric Blue
                Color(0xFF0284C7), // Vibrant Cyan-Blue
              ],
              shadowColor: const Color(0xFF2563EB),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BuyOldBootScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AnimatedOldBootCard(
              title: 'Sell Old Boot',
              subtitle: 'Cash / Trade',
              badgeText: 'INSTANT',
              icon: Icons.currency_exchange_rounded,
              gradientColors: const [
                Color(0xFF9A1B38), // Deep Ruby Red
                Color(0xFFDC2626), // Bold Coral Flame
                Color(0xFFEA580C), // Radiant Sunset Orange
              ],
              shadowColor: const Color(0xFFEA580C),
              onTap: () {
                if (!controller.loggedIn.value) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SignUpScreen()),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SellOldProductScreen(),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildCustomerServiceFab(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: 'customer_service_fab',
        onPressed: () => _showCustomerServiceSheet(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        tooltip: 'Customer Service',
        child: const Icon(
          Icons.support_agent_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  void _showCustomerServiceSheet(BuildContext context) {
    const rawNumber = '+880 1346-444121';
    final cleanDigits = rawNumber.replaceAll(RegExp(r'\D'), '');
    final waNumber = cleanDigits.startsWith('88')
        ? cleanDigits
        : (cleanDigits.startsWith('0') ? '88$cleanDigits' : '880$cleanDigits');
    final telNumber = cleanDigits.startsWith('880') ? '+$cleanDigits' : (cleanDigits.startsWith('0') ? cleanDigits : '0$cleanDigits');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer Service',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'How would you like to reach us?',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Option 1: Call
              _buildContactOptionTile(
                icon: Icons.phone_in_talk_rounded,
                iconColor: Colors.white,
                iconBgColor: const Color(0xFF1976D2),
                title: 'Call Support',
                subtitle: rawNumber,
                badgeText: 'Voice Call',
                badgeColor: Colors.blue.shade50,
                badgeTextColor: Colors.blue.shade800,
                onTap: () {
                  Navigator.pop(ctx);
                  _makePhoneCall(telNumber, context);
                },
              ),
              const SizedBox(height: 12),
              // Option 2: WhatsApp
              _buildContactOptionTile(
                icon: Icons.chat_rounded,
                iconColor: Colors.white,
                iconBgColor: const Color(0xFF25D366),
                title: 'WhatsApp Message',
                subtitle: rawNumber,
                badgeText: 'Instant',
                badgeColor: const Color(0xFFE8F5E9),
                badgeTextColor: const Color(0xFF2E7D32),
                onTap: () {
                  Navigator.pop(ctx);
                  _openWhatsApp(waNumber, context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactOptionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: iconBgColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber, BuildContext context) async {
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone dialer: $phoneNumber')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phoneNumber, BuildContext context) async {
    final uri = Uri.parse('https://wa.me/$phoneNumber');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening WhatsApp: $e')),
        );
      }
    }
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
      physics: const SmoothGlideScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildBrandItem(context, 'Adidas', 'assets/icon/adidas.png'),
          _buildBrandItem(context, 'Nike', 'assets/icon/Nike.png'),
          _buildBrandItem(context, 'Puma', 'assets/icon/puma.png'),
          _buildBrandItem(context, 'New Balance', 'assets/icon/new_balance.png'),
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
                    color: Colors.black.withValues(alpha: 0.05),
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
      final List<Map<String, String>> categories = [
        {'name': 'Boots', 'icon': 'assets/icon/boots.png'},
        {'name': 'Sneaker', 'icon': 'assets/icon/sneaker.png'},
        {'name': 'Slippers', 'icon': 'assets/icon/slippers.png'},
        {'name': 'Jersey', 'icon': 'assets/icon/jersey.png'},
        {'name': 'Pant', 'icon': 'assets/icon/pant.png'},
        {'name': 'Gloves', 'icon': 'assets/icon/gloves.png'},
        if (controller.showAllCategories.value) ...[
          {'name': 'Bag', 'icon': 'assets/icon/bag.png'},
          {'name': 'Safe Guard', 'icon': 'assets/icon/safeguard.png'},
          {'name': 'Socks', 'icon': 'assets/icon/socks.png'},
          {'name': 'Others', 'icon': 'assets/icon/other.png'},
        ],
      ];

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            for (int i = 0; i < categories.length; i += 2)
              Row(
                children: [
                  Expanded(
                    child: _buildCatagoryItem(
                      context,
                      categories[i]['name']!,
                      categories[i]['icon']!,
                    ),
                  ),
                  if (i + 1 < categories.length)
                    Expanded(
                      child: _buildCatagoryItem(
                        context,
                        categories[i + 1]['name']!,
                        categories[i + 1]['icon']!,
                      ),
                    )
                  else
                    const Expanded(child: SizedBox.shrink()),
                ],
              ),
            _buildMoreCategoryButton(),
          ],
        ),
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
                    'AJKER',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.flash_on, color: Colors.orange, size: 24),
                  const SizedBox(width: 4),
                  const Text(
                    'OFFER',
                    style: TextStyle(
                      fontSize: 20,
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
                  physics: const SmoothGlideScrollPhysics(),
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
            duration: const Duration(milliseconds: 600),
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

  Widget _buildMessageNavIcon() {
    final unreadMessages = controller.unreadMessageCount.value;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.message),
        if (unreadMessages > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadMessages > 99 ? '99+' : unreadMessages.toString(),
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
        height: 52,
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
}

class _AnimatedOldBootCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final List<Color> gradientColors;
  final Color shadowColor;
  final VoidCallback onTap;

  const _AnimatedOldBootCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  State<_AnimatedOldBootCard> createState() => _AnimatedOldBootCardState();
}

class _AnimatedOldBootCardState extends State<_AnimatedOldBootCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.shadowColor.withValues(alpha: 0.32),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Ambient geometric depth circles
              Positioned(
                right: -14,
                top: -18,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -20,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),

              // Animated diagonal light sheen sweep
              AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return FractionalTranslation(
                    translation: Offset(
                      (_shimmerController.value * 3.5) - 1.2,
                      0,
                    ),
                    child: Transform.rotate(
                      angle: 0.45,
                      child: Container(
                        width: 40,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Foreground card content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // Modern frosted glass icon box
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 21),
                    ),
                    const SizedBox(width: 8),

                    // Title + Badge + Subtitle
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.badgeText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Sleek arrow button
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
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
    return SizedBox(
      width: 85,
      child: Text(_displayedText, style: widget.style),
    );
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
                  stock: int.tryParse(product['stock']?.toString() ?? '1') ?? 1,
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
                    memCacheWidth: 350,
                    memCacheHeight: 350,
                    placeholder:
                        (_, __) => const ShimmerWidget(
                          child: SkeletonContainer(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
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
class _ProductSliverGrid extends StatelessWidget {
  final HomeController controller;
  const _ProductSliverGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isInitial = controller.isInitialLoading.value;
      final items = controller.products;

      // Pre-render skeleton cards with the exact same 255px grid geometry
      // while loading so cards take their full space from the very first frame.
      if (isInitial || items.isEmpty) {
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 255,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => const ProductCardSkeleton(),
              childCount: 6,
            ),
          ),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 255,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final product = items[index];
              final productId = product['id']?.toString() ?? index.toString();
              return ProductItem(
                key: ValueKey(productId),
                productId: productId,
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
                goldCoin:
                    double.tryParse(product['gold_coin']?.toString() ?? '0') ??
                    0.0,
                brand: product['brand']?.toString() ?? '',
                imageTwo: product['imageTwo']?.toString() ?? '',
                imageThree: product['imageThree']?.toString() ?? '',
                size: product['size']?.toString() ?? '',
                stock: int.tryParse(product['stock']?.toString() ?? '1') ?? 1,
                deliveryFee: product['deliveryFee']?.toString() ?? '',
                createdAt: product['createdAt'],
              );
            },
            childCount: items.length,
            findChildIndexCallback: (Key key) {
              if (key is ValueKey) {
                final target = key.value.toString();
                final idx = items.indexWhere(
                  (p) => (p['id']?.toString() ?? '') == target,
                );
                return idx == -1 ? null : idx;
              }
              return null;
            },
          ),
        ),
      );
    });
  }
}

class _LoadMoreSliver extends StatelessWidget {
  final HomeController controller;
  const _LoadMoreSliver({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingMore.value) {
        // Reserve the full 255px height for upcoming pagination cards so there is no layout jump
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 255,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => const ProductCardSkeleton(),
              childCount: 2,
            ),
          ),
        );
      }
      return const SliverToBoxAdapter(child: SizedBox(height: 20));
    });
  }
}


/// Silky-smooth gliding scroll physics with extended, gradual deceleration.
class SmoothGlideScrollPhysics extends ClampingScrollPhysics {
  final double frictionCoefficient;

  const SmoothGlideScrollPhysics({
    super.parent,
    this.frictionCoefficient = 0.0068, // Lower friction allows the stopping animation to decelerate slowly and take more time
  });

  @override
  SmoothGlideScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothGlideScrollPhysics(
      parent: buildParent(ancestor),
      frictionCoefficient: frictionCoefficient,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);

    // If out of bounds, let ClampingScrollPhysics clamp smoothly at the boundaries
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    // Allow the stopping animation to play out gently all the way down to a whisper (< 4.0 px/s)
    // so it takes more time and slows down with an extended, graceful curve
    if (velocity.abs() < 4.0) {
      return null;
    }

    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      friction: frictionCoefficient,
      tolerance: Tolerance(velocity: 4.0, distance: tolerance.distance),
    );
  }
}
