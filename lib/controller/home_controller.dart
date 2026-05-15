import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/services/auth.dart';
import 'package:dadu/services/firebase.dart';
import 'package:dadu/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  HomeController({dataBase? db, Auth? auth})
    : db = db ?? dataBase(),
      auth = auth ?? Auth();

  final dataBase db;
  final Auth auth;

  late final NotificationService notificationService = NotificationService(db);

  final RxBool isInitialLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool loggedIn = false.obs;
  final RxBool profileImageLoading = false.obs;
  final RxBool showSearchResults = false.obs;
  final RxBool isSearchReady = false.obs;
  final RxBool giftBannerVisible = false.obs;

  final RxInt selectedIndex = 0.obs;
  final RxInt currentBannerIndex = 0.obs;
  final RxInt cartCount = 0.obs;
  final RxInt timerTick = 0.obs;


  final RxnString profileImageUrl = RxnString();

  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> banners = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> flashProducts = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> newArrivalProducts =
      <Map<String, dynamic>>[].obs;

  final RxList<String> searchResults = <String>[].obs;
  final RxString searchQuery = ''.obs;

  final ScrollController scrollController = ScrollController();
  final PageController bannerPageController = PageController();
  final TextEditingController searchController = TextEditingController();

  DocumentSnapshot? lastDocument;
  Fuzzy<String>? fuzzy;

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
    unawaited(_recordLoginTime());

    await loadInitialProducts();

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
        unawaited(_loadProfileImage(user.email!));
        _listenToCartCount(user.email!);
      }
    } else {
      loggedIn.value = false;
      profileImageUrl.value = null;
      cartCount.value = 0;
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
    await loadBanners();

    await Future<void>.delayed(const Duration(milliseconds: 220));
    await loadFlashSaleProducts();

    await Future<void>.delayed(const Duration(milliseconds: 220));
    await loadNewArrivalProducts();

    await Future<void>.delayed(const Duration(milliseconds: 280));
    await _loadSearchIndex();
  }

  Future<void> loadInitialProducts() async {
    isInitialLoading.value = true;

    final initialProducts = await db.getProduct();
    products.assignAll(initialProducts);

    if (initialProducts.isNotEmpty) {
      lastDocument = initialProducts.last['docSnapshot'] as DocumentSnapshot?;
    } else {
      lastDocument = null;
    }

    isInitialLoading.value = false;
  }

  Future<void> loadMoreProducts() async {
    if (isLoadingMore.value || isInitialLoading.value) return;
    if (lastDocument == null) return;
    if (searchController.text.trim().isNotEmpty) return;

    isLoadingMore.value = true;

    final moreProducts = await db.getProduct(startAfterDoc: lastDocument);

    if (moreProducts.isNotEmpty) {
      lastDocument = moreProducts.last['docSnapshot'] as DocumentSnapshot?;
      products.addAll(moreProducts);
    } else {
      lastDocument = null;
    }

    isLoadingMore.value = false;
  }

  Future<void> loadBanners() async {
    final bannerData = await db.getBanners();
    banners.assignAll(bannerData);

    if (banners.length > 1) {
      _startBannerAutoScroll();
    }
  }

  Future<void> loadFlashSaleProducts() async {
    final items = await db.getFlashSaleProducts();
    flashProducts.assignAll(items);
  }

  Future<void> loadNewArrivalProducts() async {
    final items = await db.getNewArrivalProducts();
    newArrivalProducts.assignAll(items);
  }

  Future<void> _loadSearchIndex() async {
    final names = await db.getProductNames();
    fuzzy = Fuzzy<String>(names, options: FuzzyOptions(threshold: 0.3));
    isSearchReady.value = true;
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

  void _runSearch(String rawQuery) {
    final query = rawQuery.trim();

    if (query.length < 2 || fuzzy == null) {
      searchResults.clear();
      showSearchResults.value = false;
      return;
    }

    final results = fuzzy!
        .search(query)
        .map((result) => result.item)
        .take(6)
        .toList();

    searchResults.assignAll(results);
    showSearchResults.value = results.isNotEmpty;
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

  void onBottomNavTap(int tappedIndex, {required VoidCallback onMessageTap}) {
    if (tappedIndex == 2) {
      onMessageTap();
      return;
    }

    selectedIndex.value = tappedIndex > 2 ? tappedIndex - 1 : tappedIndex;
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
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
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
    }, onError: (_) {
      cartCount.value = 0;
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
