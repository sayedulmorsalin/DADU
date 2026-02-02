import 'dart:async';
import 'dart:ui';
import 'package:dadu/screen/product/product_details.dart';
import 'package:dadu/screen/user/cart.dart';
import 'package:dadu/screen/user/profile.dart';
import 'package:dadu/screen/authentication/sign_up_first.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../component/gitf_box_banner.dart';
import '../../services/notification_service.dart';
import 'brands.dart';
import 'gift_box.dart';
import 'info_banner.dart';
import 'product_item.dart';
import '../../services/auth.dart';
import '../../services/firebase.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {


  List<Map<String, dynamic>> flashProducts = [];

  Future<void> loadFlashSaleProducts() async {
    flashProducts = await db.getFlashSaleProducts();
    setState(() {});
  }
  List<Map<String, dynamic>> newArrivalProducts = [];

  Future<void> loadNewArrivalProducts() async {
    newArrivalProducts = await db.getNewArrivalProducts();
    setState(() {});
  }


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
  bool showFab = false;
  bool loggedin = false;
  String? profileImageUrl;
  bool profileImageLoading = false;

  List<Map<String, dynamic>> banners = [];
  int currentBannerIndex = 0;
  PageController bannerPageController = PageController();
  Timer? bannerAutoScrollTimer;
  Timer? flashTimer;
  late AnimationController flashAnimController;
  late Animation<double> flashBounce;

  bool showSearchResults = false;

  List<String> productNames = [];
  List<String> searchResults = [];

  late NotificationService notificationService;




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

    notificationService = NotificationService(db);
    notificationService.init();

    initializeData();
    _loadBanners();
    flashTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    flashAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700),
    );

    flashBounce = Tween<double>(begin: 0.0, end: 8.0)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(flashAnimController);

    flashAnimController.repeat(reverse: true);

    loadFlashSaleProducts();
    loadNewArrivalProducts();


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

  Widget flashSaleItem(Map<String, dynamic> product) {
    final String title = product['name'] ?? 'No Name';
    final String image = product['image5'] ??
        product['image20'] ??
        'assets/demo_item_image/d1.jpg';
    final dynamic expire = product['flash-expire'];
    final String remaining = formatRemainingTime(expire);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetails(
                productid: product['id'],
                title: product['name'],
                price: product["price"],
                image20: product['image20'],
                description: product['details'],
                videoLink: product['videoLink'],
                brand: product['brand'],
                image5: product['image5'],
              ),
            ),
          );
        },
        child: Padding(padding: EdgeInsets.all(8),child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(

                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  image,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Image.asset('assets/demo_item_image/d1.jpg'),
                ),
              ),
            ),

            SizedBox(height: 4),

            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),

            SizedBox(height: 2),

            Text(
              remaining == "Expired"
                  ? "Expired"
                  : "⏳ $remaining",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: remaining == "Expired" ? Colors.red : Colors.green,
              ),
            ),

            SizedBox(height: 2),

            Text(
              "Price: ৳${product['price']}",
              style: TextStyle(
                fontSize: 18,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),)
      ),
    );
  }


  String formatRemainingTime(dynamic ts) {
    if (ts == null) return "Expired";

    DateTime end;

    if (ts is Timestamp) {
      end = ts.toDate();
    }
    else if (ts is String) {
      end = DateTime.tryParse(ts) ?? DateTime.now();
    }
    else if (ts is DateTime) {
      end = ts;
    }
    else {
      return "Expired";
    }

    Duration diff = end.difference(DateTime.now());

    if (diff.isNegative) return "Expired";

    String two(int n) => n.toString().padLeft(2, "0");

    return "${two(diff.inHours)}:${two(diff.inMinutes % 60)}:${two(diff.inSeconds % 60)}";
  }



  @override
  void dispose() {
    flashTimer?.cancel();
    bannerAutoScrollTimer?.cancel();
    flashAnimController.dispose();
    bannerPageController.dispose();
    super.dispose();
  }

  Future<void> _loadBanners() async {
    try {
      final bannerData = await db.getBanners();
      if (mounted) {
        setState(() {
          banners = bannerData;
        });

        if (banners.length > 1) {
          _startAutoScroll();
        }
      }
    } catch (e) {
      print("Error loading banners: $e");
    }
  }


  void _startAutoScroll() {
    bannerAutoScrollTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (bannerPageController.hasClients && banners.length > 1) {
        final nextPage = (currentBannerIndex + 1) % banners.length;
        bannerPageController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
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
    productNames = await db.getProductNames();

    fuzzy = Fuzzy(
      productNames,
      options: FuzzyOptions(
        threshold: 0.3,
      ),
    );

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

  void handleSearch(String query) {
    query = query.trim();

    if (query.length < 2) {
      setState(() {
        searchResults.clear();
        showSearchResults = false;
      });
      return;
    }

    final results = fuzzy.search(query);

    setState(() {
      searchResults =
          results.map((r) => r.item.toString()).take(6).toList();
      showSearchResults = true;
    });
  }


  void _navigateToProfile() async {
    if (loggedin) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Profile()),
      );
      if (_auth.currentUser?.email != null) {
        _loadProfileImage(_auth.currentUser!.email!);
      }
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SignUpScreen()),
      );
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
          : null,
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
                          onChanged: handleSearch,
                          onSubmitted: handleSearch,
                          decoration: InputDecoration(
                            hintText: 'Search (e.g., nike 11)',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey[300],
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10)),
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

                if (showSearchResults)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 6),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final productName = searchResults[index];

                        return ListTile(
                          title: Text(productName),
                          onTap: () async {
                            final product = await db.getProductByName(productName);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetails(
                                  productid: product['id'],
                                  title: product['name'],
                                  price: product["price"],
                                  image20: product['image20'],
                                  description: product['details'],
                                  videoLink: product['videoLink'],
                                  brand: product['brand'],
                                  image5: product['image5'],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 10),


                if (banners.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Container(
                      height: MediaQuery.of(context).size.width / 2.16,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: bannerPageController,
                            itemCount: banners.length,
                            onPageChanged: (index) {
                              setState(() {
                                currentBannerIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final banner = banners[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[300],
                                  image: banner['imageUrl'] != null
                                      ? DecorationImage(
                                    image: NetworkImage(banner['imageUrl']),
                                    fit: BoxFit.cover,
                                  )
                                      : const DecorationImage(
                                    image: AssetImage('assets/icon/banner.jpg'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                    },
                                    child: Container(),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Page Indicators
                          if (banners.length > 1)
                            Positioned(
                              bottom: 10,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(banners.length, (index) {
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: currentBannerIndex == index
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.5),
                                    ),
                                  );
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Container(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.width / 2.16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[300],
                        image: const DecorationImage(
                          image: AssetImage('assets/icon/banner.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  children: [
                    _buildBrandItem("Adidas", "assets/icon/adidas.png"),
                    _buildBrandItem("Nike", "assets/icon/Nike.png"),
                    _buildBrandItem("Puma", "assets/icon/puma.png"),
                    _buildBrandItem("Gloves", "assets/icon/gloves.png"),
                    _buildBrandItem("Jersey", "assets/icon/jersey.png"),
                    _buildBrandItem("Pant", "assets/icon/pant.png"),
                    _buildBrandItem("Dadu", "assets/logo/black_logo.png"),
                    _buildBrandItem("Others", "assets/icon/other.png"),
                  ],
                ),


                if (flashProducts.isNotEmpty)
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red, Colors.red.shade100],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedBuilder(
                              animation: flashAnimController,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, -flashBounce.value),
                                  child: child,
                                );
                              },
                              child: Text(
                                "Flash Sale 🔥",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            SizedBox(height: 10),

                            SizedBox(
                              height: 270,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: flashProducts.length,
                                itemBuilder: (context, index) {
                                  final product = flashProducts[index];
                                  return Container(
                                    width: 180,
                                    margin: EdgeInsets.only(right: 10),
                                    child: flashSaleItem(product),
                                  );
                                },
                              ),
                            ),

                          ],
                    ),
                  ),
                  )
                else
                  SizedBox(),

                if (newArrivalProducts.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red, Colors.yellow],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedBuilder(
                            animation: flashAnimController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, -flashBounce.value),
                                child: child,
                              );
                            },
                            child: Text(
                              "New Arrivals 🔥",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          SizedBox(height: 10),

                          SizedBox(
                            height: 270,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: newArrivalProducts.length,
                              itemBuilder: (context, index) {
                                final product = newArrivalProducts[index];
                                return Container(
                                  width: 180,
                                  margin: EdgeInsets.only(right: 10),
                                  child: flashSaleItem(product),
                                );
                              },
                            ),
                          ),

                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(),


                StreamBuilder<String?>(
                  stream: db.getVersionStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      final version = int.tryParse(snapshot.data!);
                      if (version != null && version > 1) {
                        return Container(
                          color: Colors.amberAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.update),
                                  SizedBox(width: 8),
                                  Text("New update is available!"),
                                ],
                              ),
                              TextButton(
                                onPressed: () async {
                                  const url = 'https://appnest-seven.vercel.app/';
                                  if (await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(Uri.parse(url));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not launch $url')),
                                    );
                                  }
                                },
                                child: const Text("UPDATE"),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                    return const SizedBox.shrink(); // Return empty when no update
                  },
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GiftBoxBanner(
                    onOpen: () {
                      final currentUser = _auth.currentUser;
                      if (currentUser?.isAnonymous==true) {
                        if (mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SignUpScreen()),
                            );
                          });

                        }
                        return;
                      }
                      else{
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => GiftBox()),
                        );
                      }
                    },
                  ),
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
                      childAspectRatio: 0.8,
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
}