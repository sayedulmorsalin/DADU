import 'dart:async';
import 'dart:ui';
import 'package:dadu/screen/user/cart.dart';
import 'package:dadu/screen/user/profile.dart';
import 'package:dadu/screen/authentication/sign_up_first.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fuzzy/fuzzy.dart';
import 'brands.dart';
import 'info_banner.dart';
import 'product_item.dart';
import '../../services/auth.dart';
import '../../services/firebase.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final dataBase db = new dataBase();
  final Auth _auth = Auth();
  late Fuzzy fuzzy;
  List<Map<String, dynamic>> allProducts = [];
  List<Map<String, dynamic>> filteredProducts = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  bool isLoadingMore = false;
  bool showSplash = true;
  DocumentSnapshot? lastDocument;
  ScrollController scrollController = ScrollController();
  double splashOpacity = 1.0;
  double blurSigma = 30.0;
  Timer? _debounce;
  bool showFab = false;
  bool loggedin = false;
  String? profileImageUrl;
  bool profileImageLoading = false;

  @override
  void initState() {
    super.initState();
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      if (currentUser.isAnonymous) {
        print("User logged in anonymously ");
      } else {
        print("Logged in user email ${currentUser.email}");
        loggedin = true;
        _loadProfileImage(currentUser.email!);
      }
    } else {
      print("Not logged in");
      _auth.anonymousLogin();
    }



    initializeData();

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          !isLoading &&
          searchController.text.isEmpty) {
        loadMoreProducts();
      }
    });
    _recordLoginTime();
  }

  // New method to load profile image
  void _loadProfileImage(String email) async {
    if (!mounted) return;

    setState(() => profileImageLoading = true);
    try {
      Map<String, dynamic>? userDetails = await db.getUserDetails(email);
      if (mounted) {
        setState(() => profileImageUrl = userDetails?['profile_pic']);
      }
    } catch (e) {
      print("Error loading profile image: $e");
    } finally {
      if (mounted) setState(() => profileImageLoading = false);
    }
  }

  Future<void> _recordLoginTime() async {
    await Future.delayed(const Duration(seconds: 1)); // Ensure auth completes
    await Auth().updateLastLogin();
  }

  Future<void> initializeData() async {
    final names = await db.getProductNames();
    fuzzy = Fuzzy(names);

    final initialProducts = await db.getProduct();
    allProducts = initialProducts;
    filteredProducts = initialProducts;

    if (initialProducts.isNotEmpty) {
      lastDocument = initialProducts.last['docSnapshot'];
    }

    setState(() {
      isLoading = false;
      blurSigma = 20.0;
      splashOpacity = 1.0;
    });

    await Future.delayed(const Duration(milliseconds: 500));
    for (int i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      setState(() {
        blurSigma = 20.0 - (i * 2);
        splashOpacity = 1.0 - (i / 10.0);
        // Show FAB when splash is almost faded (e.g., 80% faded)
        if (i > 7) showFab = true;
      });
    }
    setState(() => showSplash = false);
  }

  Future<void> loadMoreProducts() async {
    if (lastDocument == null) return;
    setState(() => isLoadingMore = true);
    final newProducts = await db.getProduct(startAfterDoc: lastDocument);
    if (newProducts.isNotEmpty) {
      lastDocument = newProducts.last['docSnapshot'];
      allProducts.addAll(newProducts);
      filteredProducts = allProducts;
    }
    setState(() => isLoadingMore = false);
  }

  void handleSearch(String query) async {
    if (query.isEmpty) {
      setState(() => filteredProducts = allProducts);
    } else {
      final results = fuzzy.search(query);
      final matchedNames = results.map((r) => r.item.toString()).toList();
      setState(() => isLoading = true);
      final matchedProducts = await db.getSearchedProduct(matchedNames);
      setState(() {
        filteredProducts = matchedProducts;
        isLoading = false;
      });
    }
  }
  // if i want to show offer aspect ratio will be 9:16 / 1080x1920
  void _showImageDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: const DecorationImage(
              image: AssetImage('assets/icon/user_icon.png'), // Your image asset
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


// Updated navigation method
  void _navigateToProfile() async {
    if (loggedin) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Profile()),
      );
      // Refresh profile image after returning
      if (_auth.currentUser?.email != null) {
        _loadProfileImage(_auth.currentUser!.email!);
      }
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SignUpScreen()),
      );
      // Check if user logged in during signup
      if (_auth.currentUser != null && !_auth.currentUser!.isAnonymous) {
        setState(() => loggedin = true);
        _loadProfileImage(_auth.currentUser!.email!);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf2f2ce),
      floatingActionButton: showFab
          ? FloatingActionButton.large(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Cart()),
          );
        },
        backgroundColor: Colors.transparent,
        child: Image.asset(
          'assets/icon/bag.png',
          width: 100,
          height: 100,
        ),
      )
          : null, // Hide completely when false
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              controller: scrollController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
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
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: (query) {
                            if (_debounce?.isActive ?? false) _debounce!.cancel();
                            _debounce = Timer(const Duration(seconds: 3), () {
                              handleSearch(query);
                            });
                          },
                          onSubmitted: handleSearch,
                          decoration: InputDecoration(
                            hintText: 'Search (e.g., nike 11)',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey[300],
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: profileImageLoading
                            ? CircularProgressIndicator(strokeWidth: 2)
                            : (loggedin && profileImageUrl != null
                            ? CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(profileImageUrl!),
                        )
                            : Icon(Icons.person)),
                        onPressed: _navigateToProfile,
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 5,
                  children: [
                    _buildBrandItem("Adidas", "assets/icon/adidas.png"),
                    _buildBrandItem("Nike", "assets/icon/Nike.png"),
                    _buildBrandItem("Puma", "assets/icon/puma.png"),
                    _buildBrandItem("Gloves", "assets/icon/gloves.png"),
                    _buildBrandItem("Others", "assets/icon/other.png"),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: InfoBanner(),
                ),
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (filteredProducts.isEmpty)
                  const Center(child: Text("No products found"))
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredProducts.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.75,
                    ),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return ProductItem(
                        productId: product['id'],
                        title: product['name'] ?? 'No Title',
                        price: '৳${product['price']?.toString() ?? '0'}',
                        imagePath:
                        product['image5'] ?? 'assets/demo_item_image/d1.jpg',
                        image20:
                        product['image20'] ?? 'assets/demo_item_image/d1.jpg',
                        description:
                        product['details'] ?? 'No details available',
                        videoLink:
                        product['videoLink'] ?? 'No videoLink available',
                        brand: product['brand'] ?? 'No brand available',
                        image5: product['image5']??'assets/demo_item_image/d1.jpg',
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
          ),
          if (showSplash)
            AnimatedOpacity(
              opacity: splashOpacity,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: blurSigma,
                        sigmaY: blurSigma,
                      ),
                      child: Container(
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedOpacity(
                            opacity: splashOpacity > 0.5 ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 400),
                            child: Image.asset('assets/icon/user_icon.png', width: 250),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBrandItem(String brand, String imagePath) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Brands(brandName: brand, brandLogo: imagePath),
          ),
        );
      },
      child: SizedBox(
        width: 100,
        height: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 30, height: 30, fit: BoxFit.contain),
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
}