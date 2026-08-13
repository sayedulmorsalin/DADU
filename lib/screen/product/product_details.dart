import 'dart:io';
import 'package:dadu/controller/home_controller.dart';
import 'package:dadu/screen/user/cart.dart';
import 'package:dadu/screen/user/check_out.dart';
import 'package:dadu/services/auth.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../model/cart_model.dart';
import '../../services/firebase.dart';
import '../../services/d1.dart';
import '../authentication/sign_up_2nd.dart';
import '../authentication/sign_up_first.dart';

class ProductDetails extends StatefulWidget {
  final String title;
  final String price;
  final String image5;
  final String image20;
  final String description;
  final String videoLink;
  final String catagory;
  final String productid;
  final double goldCoin;
  final String brand;
  final String imageTwo;
  final String imageThree;
  final String size;
  final int stock;
  final String deliveryFee;
  final dynamic createdAt;

  const ProductDetails({
    super.key,
    required this.title,
    required this.price,
    required this.image20,
    required this.description,
    required this.videoLink,
    required this.catagory,
    required this.productid,
    required this.image5,
    this.goldCoin = 0.0,
    this.brand = '',
    this.imageTwo = '',
    this.imageThree = '',
    this.size = '',
    this.stock = 0,
    this.deliveryFee = '',
    this.createdAt,
  });

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails>
    with SingleTickerProviderStateMixin {
  final dataBase db = new dataBase();
  String? selectedSize;
  final Auth _auth = Auth();
  String Address = "";
  List<CartItem> cartItems = [];
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _sizeSectionKey = GlobalKey();
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  int _currentPage = 0;

  final ApiService _apiService = ApiService();
  bool _isLoadingReviews = true;
  Map<String, dynamic>? _reviewsData;
  bool _isCheckingEligibility = true;
  Map<String, dynamic>? _eligibilityData;

  bool _showReviewForm = false;
  int _selectedRating = 5;
  final TextEditingController _reviewCommentController = TextEditingController();
  File? _reviewImageFile;
  bool _isSubmittingReview = false;

  @override
  void initState() {
    super.initState();
    selectedSize = null;
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _loadReviewsAndEligibility();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _blinkController.dispose();
    _reviewCommentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _scrollToAndHighlightSize() {
    if (_sizeSectionKey.currentContext != null) {
      Scrollable.ensureVisible(
        _sizeSectionKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }

    _blinkController.reset();
    _blinkController.repeat(reverse: true, period: const Duration(milliseconds: 300));

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _blinkController.stop();
        _blinkController.reset();
      }
    });
  }

  Future<void> _loadReviewsAndEligibility() async {
    setState(() {
      _isLoadingReviews = true;
      _isCheckingEligibility = true;
    });

    final reviews = await _apiService.fetchProductReviews(widget.productid);
    final eligibility = await _apiService.checkReviewEligibility(widget.productid);

    if (mounted) {
      setState(() {
        _reviewsData = reviews;
        _isLoadingReviews = false;
        _eligibilityData = eligibility;
        _isCheckingEligibility = false;
      });
    }
  }

  Future<void> _pickReviewImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (image != null) {
        setState(() {
          _reviewImageFile = File(image.path);
        });
      }
    } catch (e) {
      // Handle image pick error silently
    }
  }

  Future<void> _submitReview() async {
    final comment = _reviewCommentController.text.trim();
    if (comment.isEmpty && _reviewImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a comment or add an image')),
      );
      return;
    }

    setState(() {
      _isSubmittingReview = true;
    });

    try {
      String? uploadedImageUrl;
      if (_reviewImageFile != null) {
        uploadedImageUrl = await _apiService.uploadReviewImage(_reviewImageFile!);
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      final userName = currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? 'Buyer';

      final result = await _apiService.submitProductReview(
        widget.productid,
        rating: _selectedRating,
        comment: comment,
        imageUrl: uploadedImageUrl,
        userName: userName,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your review has been published.'),
            backgroundColor: Colors.green,
          ),
        );
        _reviewCommentController.clear();
        setState(() {
          _reviewImageFile = null;
          _showReviewForm = false;
        });
        await _loadReviewsAndEligibility();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to submit review'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReview = false;
        });
      }
    }
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<bool> requestImagePermission() async {
    final photosPermission = await Permission.photos.request();
    if (photosPermission.isGranted) return true;

    final storagePermission = await Permission.storage.request();
    if (storagePermission.isGranted) return true;

    return false;
  }

  Future<void> saveImageToDevice(String url) async {
    FileDownloader.downloadFile(
      url: url,
      name: "dadu_${DateTime.now().millisecondsSinceEpoch}.jpg",
      downloadDestination: DownloadDestinations.publicDownloads,
      subPath: "Dadu",
      onProgress: (String? fileName, double progress) {},
      onDownloadCompleted: (String path) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Saved to: $path")));
      },
      onDownloadError: (String errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Download error: $errorMessage")),
        );
      },
    );
  }

  Widget _buildDynamicSizeButtons() {
    if (widget.size.isEmpty || widget.size == "no size") {
      return const SizedBox.shrink();
    }

    List<String> sizes = widget.size
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sizes.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _blinkAnimation,
      builder: (context, child) {
        final blinkVal = _blinkAnimation.value;
        final blinkBorderColor = Color.lerp(Colors.grey.shade300, Colors.red.shade600, blinkVal)!;
        final blinkBgColor = Color.lerp(Colors.white, Colors.red.shade50, blinkVal)!;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: sizes.map((size) {
              final isSelected = selectedSize == size;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedSize = size;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : blinkBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.black
                            : (blinkVal > 0 ? blinkBorderColor : Colors.grey.shade300),
                        width: isSelected ? 1.5 : (1.5 + blinkVal * 1.0),
                      ),
                      boxShadow: blinkVal > 0 && !isSelected
                          ? [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.3 * blinkVal),
                                blurRadius: 8 * blinkVal,
                                spreadRadius: 1 * blinkVal,
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      size,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (blinkVal > 0.5 ? Colors.red.shade800 : Colors.black),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _navigateToChat() {
    final HomeController homeController = Get.find<HomeController>();
    homeController.onBottomNavTap(3); // Index 3 is Message tab
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  bool get _isSizeRequired =>
      widget.size.isNotEmpty && widget.size.toLowerCase() != "no size";

  void _addToCart() async {
    if (_isSizeRequired && selectedSize == null) {
      _scrollToAndHighlightSize();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a size first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      if (currentUser.isAnonymous) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SignUpScreen()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You do not have account please create one'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        Map<String, dynamic>? userDetails = await db.getUserDetails(
          currentUser.email.toString(),
        );
        Address = userDetails?['address'] ?? '';
        if (Address.isEmpty || Address == '') {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SignUpScreen2()),
            );
          }
          return;
        } else {
          Map<String, dynamic> cartItems = Map<String, dynamic>.from(
            userDetails?['cart_item'] ?? {},
          );

          String productId = widget.productid;
          String size = selectedSize ?? "default";

          if (cartItems.containsKey(productId)) {
            if (cartItems[productId] is int) {
              cartItems[productId] = {"default": cartItems[productId]};
            }
          }

          if (cartItems.containsKey(productId)) {
            Map<String, dynamic> sizeMap = Map<String, dynamic>.from(
                cartItems[productId] is Map ? cartItems[productId] : {});

            if (sizeMap.containsKey(size)) {
              int currentQty = int.tryParse(sizeMap[size].toString()) ?? 0;
              sizeMap[size] = currentQty + 1;
            } else {
              sizeMap[size] = 1;
            }
            cartItems[productId] = sizeMap;
          } else {
            cartItems[productId] = {size: 1};
          }

          await db.updateUserDetails(currentUser.email!, {
            "cart_item": cartItems,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.title} added to cart'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      _auth.anonymousLogin();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignUpScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You do not have account please create one'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  double _parsePrice(String priceStr) {
    String cleaned = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  void _buyNow() async {
    if (_isSizeRequired && selectedSize == null) {
      _scrollToAndHighlightSize();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a size first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      if (currentUser.isAnonymous) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SignUpScreen()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You do not have account please create one'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        Map<String, dynamic>? userDetails = await db.getUserDetails(
          currentUser.email.toString(),
        );
        Address = userDetails?['address'] ?? '';
        if (Address.isEmpty || Address == '') {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SignUpScreen2()),
            );
          }
          return;
        } else {
          double priceValue = _parsePrice(widget.price);
          double deliveryFeeValue = double.tryParse(
                  widget.deliveryFee.replaceAll(RegExp(r'[^\d.]'), '')) ??
              0.0;
          List<CartItem> checkoutItems = [
            CartItem(
              id: widget.productid,
              name: widget.title,
              price: priceValue,
              quantity: 1,
              imageUrl: widget.image5,
              catagory: widget.catagory,
              size: selectedSize ?? "default",
              deliveryFee: deliveryFeeValue,
              freeCoin: widget.goldCoin,
            ),
          ];

          if (currentUser.email != null) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(child: CircularProgressIndicator()),
            );
            final hasPending = await db.hasPendingOrder(currentUser.email!);
            if (context.mounted) Navigator.pop(context);

            if (hasPending && context.mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Order In Progress'),
                  content: const Text(
                    'You currently have an active order in progress (Verify, Shipping, or To Receive).\n\nYou cannot place a new order until your current order is delivered.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
              return;
            }
          }

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CheckOut(
                  cartItems: checkoutItems,
                  totalAmount: priceValue,
                ),
              ),
            );
          }
        }
      }
    } else {
      _auth.anonymousLogin();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignUpScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You do not have account please create one'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showShareOptions() {
    final String deepLink = "https://dadubd.com/product?id=${widget.productid}";

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Share Product",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text("Copy Link"),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: deepLink));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Link copied to clipboard")),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text("Share via..."),
                onTap: () {
                  Navigator.pop(context);
                  Share.share(
                    "Check out this product on Dadu: ${widget.title}\n$deepLink",
                    subject: widget.title,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> images = [];

    // Adding images in order: Image Three, Two, One (image20)
    // This handles the user's request to "reverse it" while maintaining
    // the exclusion of the primary image (image5).
    if (widget.imageThree.isNotEmpty) images.add(widget.imageThree);
    if (widget.imageTwo.isNotEmpty) images.add(widget.imageTwo);
    if (widget.image20.isNotEmpty && widget.image20 != widget.image5) {
      images.add(widget.image20);
    }

    // If no specific details images are found, we follow the user's rule:
    // "don't show primary image on product details page".
    // However, for UX, if absolutely nothing else exists, we might want a placeholder
    // but here we strictly follow the instruction of showing imageOne, Two, Three.

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.share, color: Colors.black),
              onPressed: _showShareOptions,
            ),
          ),
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.download, color: Colors.black),
              onPressed: () => saveImageToDevice(widget.image20),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: widget.productid,
                  child: Container(
                    height: 450,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        images.isNotEmpty
                            ? (images.length > 1
                                ? PageView.builder(
                                    controller: _pageController,
                                    itemCount: images.length,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentPage = index;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      return Image.network(images[index],
                                          fit: BoxFit.cover);
                                    },
                                  )
                                : Image.network(
                                    images[0],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ))
                            : Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.image,
                                      size: 100, color: Colors.grey),
                                ),
                              ),
                        if (images.length > 1)
                          Positioned(
                            top: 100,
                            right: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${_currentPage + 1} / ${images.length}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (images.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: SizedBox(
                              height: 70,
                              child: Center(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  scrollDirection: Axis.horizontal,
                                  itemCount: images.length,
                                  itemBuilder: (context, index) {
                                    bool isSelected = _currentPage == index;
                                    return GestureDetector(
                                      onTap: () {
                                        _pageController.animateToPage(
                                          index,
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.black
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Image.network(
                                            images[index],
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontFamily: 'Georgia',
                                    ),
                                  ),
                                  if (widget.brand.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      "Brand: ${widget.brand}",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                  if ([
                                    'Boots Master Grade',
                                    'Boots Master Grade Copy',
                                    'Boots Copy 4 Grade',
                                    'Boots China Copy',
                                    'Boots Turf'
                                  ].contains(widget.catagory)) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      "Category: ${widget.catagory}",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.stars,
                                      color: Colors.orange, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Cash back ${widget.goldCoin.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              widget.price,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle("Availability"),
                        const SizedBox(height: 8),
                        Text(
                          widget.stock > 0 ? "Available" : "Not Available",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: widget.stock > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildVideoSection(),
                        const SizedBox(height: 25),
                        if (widget.size.isNotEmpty &&
                            widget.size != "no size") ...[
                          const SizedBox(height: 25),
                          _buildSizeSection(_buildDynamicSizeButtons()),
                        ],
                        const SizedBox(height: 25),
                        _buildSectionTitle("Description"),
                        const SizedBox(height: 10),
                        Text(
                          widget.description,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildReviewsSection(),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomNavigationBar(),
          _buildFabMenu(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  Widget _buildVideoSection() {
    return InkWell(
      onTap: () {
        if (widget.videoLink == "No videoLink available" ||
            widget.videoLink.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video is not available now')),
          );
        } else {
          _launchURL(widget.videoLink);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white),
            ),
            const SizedBox(width: 15),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Product Video",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red),
                ),
                Text(
                  "Watch for more details",
                  style: TextStyle(fontSize: 13, color: Colors.redAccent),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSection(Widget sizeWidget) {
    return AnimatedBuilder(
      animation: _blinkAnimation,
      builder: (context, child) {
        final blinkVal = _blinkAnimation.value;
        final sectionBorderColor = Color.lerp(Colors.transparent, Colors.red.shade400, blinkVal)!;
        final sectionBgColor = Color.lerp(Colors.transparent, Colors.red.shade50.withValues(alpha: 0.5), blinkVal)!;

        return Container(
          key: _sizeSectionKey,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sectionBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: sectionBorderColor,
              width: blinkVal > 0 ? 2.0 : 0.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildSectionTitle("Select Size"),
                  if (_isSizeRequired && selectedSize == null) ...[
                    const SizedBox(width: 8),
                    Text(
                      "*",
                      style: TextStyle(
                        color: blinkVal > 0.3 ? Colors.red : Colors.red.shade400,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  if (blinkVal > 0) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Please select a size!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              sizeWidget,
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (context) => Cart())),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shopping_cart_outlined,
                    color: Colors.black),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (widget.stock > 0) ? _addToCart : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Add to Cart',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ElevatedButton(
                onPressed: (widget.stock > 0) ? _buyNow : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Buy Now',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFabMenu() {
    return Positioned(
      bottom: 100,
      right: 16,
      child: FloatingActionButton(
        onPressed: _navigateToChat,
        backgroundColor: Colors.greenAccent,
        child: const Icon(Icons.message, color: Colors.black),
      ),
    );
  }

  Widget _buildReviewsSection() {
    final double avgRating = (_reviewsData?['averageRating'] ?? 0.0).toDouble();
    final int totalReviews = _reviewsData?['totalReviews'] ?? 0;
    final Map<String, dynamic> starBreakdown = Map<String, dynamic>.from(_reviewsData?['starBreakdown'] ?? {});
    final List<dynamic> reviewsList = _reviewsData?['reviews'] as List<dynamic>? ?? [];

    final bool isEligible = _eligibilityData?['eligible'] == true;
    final bool hasReviewed = _eligibilityData?['hasReviewed'] == true;
    final String ineligibleReason = _eligibilityData?['reason'] ?? 'Only verified buyers of delivered orders can write a review.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("Customer Reviews"),
            if (totalReviews > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$avgRating ($totalReviews)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Rating Overview Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // Left: Big Rating Number
              Column(
                children: [
                  Text(
                    avgRating > 0 ? avgRating.toStringAsFixed(1) : "0.0",
                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < avgRating.floor()
                            ? Icons.star
                            : (index < avgRating ? Icons.star_half : Icons.star_border),
                        color: Colors.amber,
                        size: 16,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$totalReviews ${totalReviews == 1 ? 'review' : 'reviews'}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              // Right: Star distribution bars
              Expanded(
                child: Column(
                  children: List.generate(5, (idx) {
                    final starNum = 5 - idx;
                    final count = (starBreakdown[starNum.toString()] ?? starBreakdown[starNum] ?? 0) as int;
                    final ratio = totalReviews > 0 ? (count / totalReviews) : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Text('$starNum', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 20,
                            child: Text(
                              '$count',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Eligibility / Review Posting Form Banner
        if (_isCheckingEligibility)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (hasReviewed)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You have submitted a review for this product. Thank you!",
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else if (isEligible)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_showReviewForm)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showReviewForm = true;
                    });
                  },
                  icon: const Icon(Icons.rate_review, color: Colors.white),
                  label: const Text('Write a Review', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade300, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Write Your Review",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _showReviewForm = false;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text("Rating", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(5, (index) {
                          final starVal = index + 1;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRating = starVal;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Icon(
                                starVal <= _selectedRating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 32,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _reviewCommentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Share details of your experience with this product...",
                          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickReviewImage,
                            icon: const Icon(Icons.add_a_photo, size: 18),
                            label: Text(_reviewImageFile != null ? "Change Photo" : "Add Photo"),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_reviewImageFile != null)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(_reviewImageFile!, width: 44, height: 44, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _reviewImageFile = null),
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmittingReview ? null : _submitReview,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade500,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSubmittingReview
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Submit Review", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.grey.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ineligibleReason,
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Reviews List
        if (_isLoadingReviews)
          const Center(child: CircularProgressIndicator())
        else if (reviewsList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              "No reviews yet. Be the first to review this product!",
              style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reviewsList.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final rev = reviewsList[index];
              final String userName = rev['userName'] ?? 'Customer';
              final int rating = parseIntSafe(rev['rating']);
              final String comment = rev['comment'] ?? '';
              final String? rawImg = rev['imageUrl'];
              final String? imgUrl = (rawImg != null && rawImg.isNotEmpty)
                  ? ApiService.resolveUrl(rawImg)
                  : null;
              final String dateStr = rev['createdAt'] ?? '';

              String formattedDate = '';
              if (dateStr.isNotEmpty) {
                try {
                  final dt = DateTime.parse(dateStr).toLocal();
                  formattedDate = DateFormat('MMM dd, yyyy').format(dt);
                } catch (_) {}
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          userName.substring(0, 1).toUpperCase(),
                          style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Row(
                              children: List.generate(5, (starIdx) {
                                return Icon(
                                  starIdx < rating ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 14,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      if (formattedDate.isNotEmpty)
                        Text(formattedDate, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(comment, style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.4)),
                  ],
                  if (imgUrl != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.contain),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: imgUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(width: 100, height: 100, color: Colors.grey.shade200),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }

  int parseIntSafe(dynamic val) {
    if (val is int) return val;
    if (val is String) return int.tryParse(val) ?? 5;
    return 5;
  }
}
