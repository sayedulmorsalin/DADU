import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:dadu/screen/product/product_details.dart';
import 'package:dadu/services/d1.dart'; // Import ApiService
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

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
        debugPrint('Notification received while terminated: ${message.data}');
        if (message.notification != null) {
          debugPrint('Notification Details: Title: ${message.notification?.title}, Body: ${message.notification?.body}, Image: ${message.notification?.android?.imageUrl ?? message.notification?.apple?.imageUrl}');
        }
        final link = message.data['link'] ?? message.data['deepLink'];
        if (link != null) {
          await _waitForNavigator(navigatorKey);
          _handleDeepLink(Uri.parse(link), navigatorKey);
        }
      }
    });

    // 2. Handle Deep Links from Notifications (when app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('Notification received while in background: ${message.data}');
      if (message.notification != null) {
        debugPrint('Notification Details: Title: ${message.notification?.title}, Body: ${message.notification?.body}, Image: ${message.notification?.android?.imageUrl ?? message.notification?.apple?.imageUrl}');
      }
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
        _handleDeepLink(initialLink, navigatorKey);
      }
    } catch (e) {
      debugPrint('Failed to get initial link: $e');
    }

    // 4. Listen for links when app is in background/foreground (Standard deep link)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri, navigatorKey);
    }, onError: (err) {
      debugPrint('Deep link stream error: $err');
    });
  }

  void handleLink(String? link) {
    if (link == null || link.isEmpty || _navigatorKey == null) return;
    try {
      final uri = Uri.parse(link);
      _handleDeepLink(uri, _navigatorKey!);
    } catch (e) {
      debugPrint('Error parsing manual link: $e');
    }
  }

  Future<void> _waitForNavigator(GlobalKey<NavigatorState> navigatorKey) async {
    int attempts = 0;
    while (navigatorKey.currentState == null && attempts < 10) {
      debugPrint('Waiting for navigator state... attempt $attempts');
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
  }

  void _handleDeepLink(Uri uri, GlobalKey<NavigatorState> navigatorKey) async {
    debugPrint('Received deep link: $uri');
    
    // Expected format: https://dadubd.com/product?id=PRODUCT_ID
    if (uri.path.contains('/product')) {
      final productId = uri.queryParameters['id'];
      debugPrint('Parsed Product ID: $productId');
      if (productId != null && productId.isNotEmpty) {
        _navigateToProduct(productId, navigatorKey);
      } else {
        debugPrint('Product ID is null or empty');
      }
    } else {
      debugPrint('Path does not contain /product: ${uri.path}');
    }
  }

  Future<void> _navigateToProduct(String productId, GlobalKey<NavigatorState> navigatorKey) async {
    debugPrint('Navigating to product: $productId');
    // Show a loading indicator or just fetch data
    try {
      final productData = await _apiService.fetchProductById(productId);
      
      if (productData == null) {
        debugPrint('Product data not found in API for ID: $productId');
        return;
      }

      if (navigatorKey.currentState == null) {
        debugPrint('Navigator state is still null in _navigateToProduct');
        return;
      }

      debugPrint('Pushing ProductDetails page for: ${productData['name']}');
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
      debugPrint('Navigation successful');
    } catch (e) {
      debugPrint('Error during navigation to product: $e');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
