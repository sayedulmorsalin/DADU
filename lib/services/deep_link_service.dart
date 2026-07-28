import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:dadu/controller/home_controller.dart';
import 'package:dadu/screen/product/brand.dart';
import 'package:dadu/screen/product/catagory.dart';
import 'package:dadu/screen/product/product_details.dart';
import 'package:dadu/screen/user/reword_ad.dart';
import 'package:dadu/services/d1.dart'; // Import ApiService
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final ApiService _apiService = ApiService(); // Use ApiService instead of database
  GlobalKey<NavigatorState>? _navigatorKey;

  void initDeepLinks(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    // 1. Handle Deep Links from Notifications (when app is terminated)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) async {
      if (message != null) {
        final link = message.data['link'] ?? message.data['deepLink'];
        if (link != null) {
          await _waitForNavigator(navigatorKey);
          _handleDeepLink(Uri.parse(link), navigatorKey);
        }
      }
    });

    // 2. Handle Deep Links from Notifications (when app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final link = message.data['link'] ?? message.data['deepLink'];
      if (link != null) {
        await _waitForNavigator(navigatorKey);
        _handleDeepLink(Uri.parse(link), navigatorKey);
      }
    });

    // 3. Check initial link when app is opened via standard deep link (Browser/Other App)
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        await _waitForNavigator(navigatorKey);
        _handleDeepLink(initialLink, navigatorKey);
      }
    } catch (e) {
      // Failed to get initial link
    }

    // 4. Listen for links when app is in background/foreground (Standard deep link)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri, navigatorKey);
    }, onError: (err) {
      // Deep link stream error
    });
  }

  void handleLink(String? link) {
    if (link == null || link.isEmpty || _navigatorKey == null) return;
    try {
      final uri = Uri.parse(link);
      _handleDeepLink(uri, _navigatorKey!);
    } catch (e) {
      // Error parsing manual link
    }
  }

  Future<void> _waitForNavigator(GlobalKey<NavigatorState> navigatorKey) async {
    int attempts = 0;
    while (navigatorKey.currentState == null && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
  }

  void _handleDeepLink(Uri uri, GlobalKey<NavigatorState> navigatorKey) async {
    final segments = uri.pathSegments;
    if (segments.isEmpty) {
      return;
    }

    final firstSegment = segments.first.toLowerCase();
    
    // 1. Product Details: /product?id=...
    if (firstSegment == 'product') {
      final productId = uri.queryParameters['id'];
      if (productId != null && productId.isNotEmpty) {
        _navigateToProduct(productId, navigatorKey);
      }
    } 
    // 2. Brand Page: /brand?name=...
    else if (firstSegment == 'brand') {
      final brandName = uri.queryParameters['name'];
      if (brandName != null && brandName.isNotEmpty) {
        _navigateToBrand(brandName, navigatorKey);
      }
    }
    // 3. Category Page: /category?name=...
    else if (firstSegment == 'category') {
      final catName = uri.queryParameters['name'];
      if (catName != null && catName.isNotEmpty) {
        _navigateToCategory(catName, navigatorKey);
      }
    }
    // 4. Earn Coins: /earn-coins
    else if (firstSegment == 'earn-coins') {
      _navigateToEarnCoins(navigatorKey);
    }
    // 5. Tab Switching: /cart, /search, /message, /profile
    else if (firstSegment == 'cart') {
      _switchToTab(1);
    } else if (firstSegment == 'search') {
      _switchToTab(2);
    } else if (firstSegment == 'message') {
      _switchToTab(3);
    } else if (firstSegment == 'profile') {
      _switchToTab(4);
    } else {
      // Unrecognized deep link segment
    }
  }

  void _switchToTab(int index) {
    try {
      final homeController = Get.find<HomeController>();
      homeController.selectedIndex.value = index;
      
      // If we are deep into a navigation stack, we might want to pop to top
      if (_navigatorKey?.currentState?.canPop() ?? false) {
        _navigatorKey?.currentState?.popUntil((route) => route.isFirst);
      }
    } catch (e) {
      // Error switching tab
    }
  }

  void _navigateToBrand(String name, GlobalKey<NavigatorState> navigatorKey) {
    final logoMap = {
      'adidas': 'assets/icon/adidas.png',
      'nike': 'assets/icon/Nike.png',
      'puma': 'assets/icon/puma.png',
      'dadu': 'assets/logo/black_logo.png',
      'mizuno': 'assets/icon/mizuno.png',
      'others': 'assets/icon/other.png',
    };
    
    final logo = logoMap[name.toLowerCase()] ?? 'assets/icon/other.png';
    
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => Brand(brandName: name, brandLogo: logo))
    );
  }

  void _navigateToCategory(String name, GlobalKey<NavigatorState> navigatorKey) {
    final logoMap = {
      'boots': 'assets/icon/boots.png',
      'gloves': 'assets/icon/gloves.png',
      'jersey': 'assets/icon/jersey.png',
      'pant': 'assets/icon/pant.png',
      'bag': 'assets/icon/bag.png',
      'safe guard': 'assets/icon/safeguard.png',
      'socks': 'assets/icon/socks.png',
      'others': 'assets/icon/other.png',
    };
    
    final logo = logoMap[name.toLowerCase()] ?? 'assets/icon/other.png';
    
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => Catagory(catagoryName: name, catagoryLogo: logo))
    );
  }

  void _navigateToEarnCoins(GlobalKey<NavigatorState> navigatorKey) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const RewordAd())
    );
  }

  Future<void> _navigateToProduct(String productId, GlobalKey<NavigatorState> navigatorKey) async {
    try {
      final productData = await _apiService.fetchProductById(productId);
      
      if (productData == null || navigatorKey.currentState == null) return;

      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => ProductDetails(
            title: productData['name'] ?? '',
            price: productData['price']?.toString() ?? '',
            image20: productData['image20'] ?? '',
            description: productData['details'] ?? '',
            videoLink: productData['videoLink'] ?? '',
            catagory: productData['catagory'] ?? 'Others',
            productid: productId,
            image5: productData['image5'] ?? '',
            goldCoin: double.tryParse(productData['gold_coin']?.toString() ?? '0') ?? 0.0,
            brand: productData['brand'] ?? '',
            imageTwo: productData['imageTwo'] ?? '',
            imageThree: productData['imageThree'] ?? '',
            size: productData['size'] ?? '',
            stock: int.tryParse(productData['stock']?.toString() ?? '0') ?? 0,
            deliveryFee: productData['deliveryFee']?.toString() ?? '',
            createdAt: productData['createdAt'],
          ),
        ),
      );
    } catch (e) {
      // Error during navigation to product
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
