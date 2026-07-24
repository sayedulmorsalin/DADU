import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/services/auth.dart';
import 'package:dadu/services/firebase.dart';
import 'package:dadu/services/d1.dart'; // Added ApiService import
import 'package:dadu/services/notification_service.dart';
import 'package:dadu/services/local_notification_db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  HomeController({dataBase? db, Auth? auth, ApiService? apiService})
    : db = db ?? dataBase(),
      auth = auth ?? Auth(),
      apiService = apiService ?? ApiService(); // Added ApiService

  final dataBase db;
  final Auth auth;
  final ApiService apiService; // Added ApiService

  late final NotificationService notificationService = NotificationService(db);

  final RxBool isInitialLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool loggedIn = false.obs;
  final RxBool profileImageLoading = false.obs;
  final RxBool showSearchResults = false.obs;
  final RxBool isSearching = false.obs;
  final RxBool isSearchReady = false.obs;
  final RxBool giftBannerVisible = false.obs;
  final RxBool showAllCategories = false.obs;

  final RxInt selectedIndex = 0.obs;
  final RxInt currentBannerIndex = 0.obs;
  final RxInt cartCount = 0.obs;
  final RxInt unreadNotificationCount = 0.obs;
  final RxInt timerTick = 0.obs;
  final RxDouble coinAmount = 0.0.obs;
  final Rxn<dynamic> flashSaleEndTime = Rxn<dynamic>();


  final RxnString profileImageUrl = RxnString();

  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> banners = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> flashProducts = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> newArrivalProducts =
      <Map<String, dynamic>>[].obs;

  final RxList<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[].obs;
  final RxString searchQuery = ''.obs;

  final ScrollController scrollController = ScrollController();
  final PageController bannerPageController = PageController();
  final TextEditingController searchController = TextEditingController();

  int apiPage = 1; // Track API pagination

  Timer? _bannerAutoScrollTimer;
  Timer? _flashTimer;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _cartSubscription;
  Worker? _searchDebounce;

  @override
  void onInit() {
    super.onInit();

    _flashTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      timerTick.value++;
    });


    _searchDebounce = debounce<String>(
      searchQuery,
      _runSearch,
      time: const Duration(milliseconds: 140),
    );

    _authSubscription = auth.authStateChanges.listen((_) {
      unawaited(_ensureAuthState());
    });

    _attachPaginationListener();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _ensureAuthState();
    unawaited(notificationService.init());
    unawaited(updateUnreadCount());
    unawaited(_recordLoginTime());

    // Only load if data is empty to save requests
    if (products.isEmpty) {
      await loadInitialProducts();
    }

    giftBannerVisible.value = true;

    unawaited(_loadSecondaryDataStaggered());
  }

  Future<void> _ensureAuthState() async {
    User? user = auth.currentUser;

    if (user == null) {
      await auth.anonymousLogin();
      user = auth.currentUser;
    }

    if (user != null && !user.isAnonymous) {
      loggedIn.value = true;
      if (user.email != null) {
        // Only fetch profile if not already loaded
        if (profileImageUrl.value == null) {
          unawaited(_loadProfileImage(user.email!));
        }
        _listenToCartCount(user.email!);
      }
    } else {
      loggedIn.value = false;
      profileImageUrl.value = null;
      cartCount.value = 0;
      coinAmount.value = 0.0;
      selectedIndex.value = 0;
      _cartSubscription?.cancel();
      _cartSubscription = null;
    }
  }

  void resetToHomeTab() {
    selectedIndex.value = 0;
  }

  Future<void> _loadSecondaryDataStaggered() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (banners.isEmpty) await loadBanners();

    await Future<void>.delayed(const Duration(milliseconds: 220));
    await loadFlashSaleProducts(forceRefresh: true);

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (newArrivalProducts.isEmpty) await loadNewArrivalProducts();

    await Future<void>.delayed(const Duration(milliseconds: 280));
    isSearchReady.value = true;
  }

  Future<void> refreshData() async {
    // Clear API cache and local lists to force a fresh fetch
    apiService.clearCache();
    products.clear();
    banners.clear();
    flashProducts.clear();
    newArrivalProducts.clear();

    // Force reload everything
    await loadInitialProducts();
    await loadBanners(forceRefresh: true);
    await loadFlashSaleProducts(forceRefresh: true);
    await loadNewArrivalProducts();
  }

  Future<void> loadInitialProducts() async {
    isInitialLoading.value = true;
    apiPage = 1;

    // Fetch products exclusively from API
    final apiProducts = await apiService.fetchProducts(limit: 20, page: apiPage);
    
    products.assignAll(apiProducts);
    if (apiProducts.isNotEmpty) {
      apiPage++;
    }

    isInitialLoading.value = false;
  }

  Future<void> loadMoreProducts() async {
    if (isLoadingMore.value || isInitialLoading.value) return;
    if (searchController.text.trim().isNotEmpty) return;

    isLoadingMore.value = true;

    final moreProducts = await apiService.fetchProducts(limit: 20, page: apiPage);
    if (moreProducts.isNotEmpty) {
      products.addAll(moreProducts);
      apiPage++;
    }

    isLoadingMore.value = false;
  }

  Future<void> loadBanners({bool forceRefresh = false}) async {
    final bannerData = await db.getBanners(forceRefresh: forceRefresh);
    banners.assignAll(bannerData);

    if (banners.length > 1) {
      _startBannerAutoScroll();
    }
  }

  Future<void> loadFlashSaleProducts({bool forceRefresh = false}) async {
    final timer = await db.getFlashSaleTimer(forceRefresh: forceRefresh);
    flashSaleEndTime.value = timer;

    DateTime? end;
    if (timer is Timestamp) {
      end = timer.toDate();
    } else if (timer is String) {
      end = DateTime.tryParse(timer);
    } else if (timer is DateTime) {
      end = timer;
    }

    if (end == null || end.isBefore(DateTime.now())) {
      flashProducts.clear();
      return;
    }

    final flashItemsData = await db.getFlashSaleProducts(forceRefresh: forceRefresh);
    final List<Map<String, dynamic>> enrichedProducts = [];

    // Collect all valid product IDs
    final List<String> productIds = [];
    for (var item in flashItemsData) {
      final productId = item['id'];
      if (productId.isNotEmpty) {
        productIds.add(productId);
      }
    }

    if (productIds.isNotEmpty) {
      // Fetch all products in one batch request
      final apiProducts = await apiService.fetchProducts(
        limit: productIds.length,
        ids: productIds,
      );

      // Create a map for quick lookup
      final productMap = {for (var p in apiProducts) p['id']: p};

      // Enrich products with flash sale specific data (price overrides)
      for (var item in flashItemsData) {
        final productId = item['id'];
        if (productMap.containsKey(productId)) {
          final apiDetails = Map<String, dynamic>.from(productMap[productId]!);
          
          if (item['price'].toString().isNotEmpty) {
            apiDetails['price'] = item['price'];
          }
          if (item['oldPrice'].toString().isNotEmpty) {
            apiDetails['oldPrice'] = item['oldPrice'];
          }
          apiDetails['flashSell'] = true;
          enrichedProducts.add(apiDetails);
        }
      }
    }

    flashProducts.assignAll(enrichedProducts);
  }

  Future<void> loadNewArrivalProducts() async {
    final items = await db.getNewArrivalProducts();
    newArrivalProducts.assignAll(items);
  }

  void onSearchChanged(String value) {
    searchQuery.value = value;
  }

  Future<Map<String, dynamic>> getProductByName(String name) {
    return db.getProductByName(name);
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
    searchResults.clear();
    showSearchResults.value = false;
  }

  Future<void> _runSearch(String rawQuery) async {
    final query = rawQuery.trim();

    if (query.length < 2) {
      searchResults.clear();
      showSearchResults.value = false;
      return;
    }

    isSearching.value = true;
    showSearchResults.value = true;

    try {
      final results = await apiService.fetchProducts(search: query, limit: 10);
      searchResults.assignAll(results);
    } catch (e) {
      debugPrint('Search error: $e');
      searchResults.clear();
    } finally {
      isSearching.value = false;
    }
  }

  void onBannerChanged(int index) {
    currentBannerIndex.value = index;
  }

  String formatFlashRemaining(dynamic ts) {
    final _ = timerTick.value;

    if (ts == null) return 'Expired';

    late final DateTime end;

    if (ts is Timestamp) {
      end = ts.toDate();
    } else if (ts is String) {
      final parsed = DateTime.tryParse(ts);
      if (parsed == null) return 'Expired';
      end = parsed;
    } else if (ts is DateTime) {
      end = ts;
    } else {
      return 'Expired';
    }

    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';

    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds left';
  }

  void onBottomNavTap(int tappedIndex) {
    selectedIndex.value = tappedIndex;
  }

  void _attachPaginationListener() {
    scrollController.addListener(() {
      if (!scrollController.hasClients) return;

      final threshold = scrollController.position.maxScrollExtent - 220;
      if (scrollController.position.pixels >= threshold) {
        unawaited(loadMoreProducts());
      }
    });
  }

  void _startBannerAutoScroll() {
    _bannerAutoScrollTimer?.cancel();
    _bannerAutoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!bannerPageController.hasClients || banners.length < 2) return;

      final next = (currentBannerIndex.value + 1) % banners.length;
      bannerPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 1000), // Slower banner transition
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> updateUnreadCount() async {
    unreadNotificationCount.value = await LocalNotificationDb().getUnreadCount();
  }

  Future<void> _loadProfileImage(String email) async {
    profileImageLoading.value = true;
    try {
      final user = await db.getUserDetails(email);
      profileImageUrl.value = user?['profile_pic'] as String?;
    } finally {
      profileImageLoading.value = false;
    }
  }

  void _listenToCartCount(String email) {
    _cartSubscription?.cancel();
    _cartSubscription = db.getUserStream(email).listen((snapshot) {
      if (!snapshot.exists) {
        cartCount.value = 0;
        return;
      }

      final data = snapshot.data();
      final cartData = data?['cart_item'] as Map<String, dynamic>? ?? {};

      var total = 0;
      for (final value in cartData.values) {
        if (value is int) {
          total += value;
        } else if (value is Map<String, dynamic>) {
          for (final qty in value.values) {
            if (qty is int) {
              total += qty;
            }
          }
        }
      }

      cartCount.value = total;
      coinAmount.value = (data?['free_delivery_info'] as num?)?.toDouble() ?? 0.0;
    }, onError: (_) {
      cartCount.value = 0;
      coinAmount.value = 0.0;
    });
  }

  Future<void> _recordLoginTime() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    await auth.updateLastLogin();
  }

  @override
  void onClose() {
    _bannerAutoScrollTimer?.cancel();
    _flashTimer?.cancel();
    _authSubscription?.cancel();
    _cartSubscription?.cancel();
    _searchDebounce?.dispose();
    scrollController.dispose();
    bannerPageController.dispose();
    searchController.dispose();
    super.onClose();
  }
}
