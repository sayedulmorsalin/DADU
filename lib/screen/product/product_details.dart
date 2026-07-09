
import 'package:dadu/screen/user/cart.dart';
import 'package:dadu/screen/user/check_out.dart';
import 'package:dadu/services/auth.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/cart_model.dart';
import '../../services/firebase.dart';
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
  });

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  final dataBase db = new dataBase();
  bool _isFabMenuOpen = false;
  String? selectedSize;
  final Auth _auth = Auth();
  String Address = "";
  List<CartItem> cartItems = [];

  @override
  void initState() {
    super.initState();

    if (widget.catagory == "Puma" ||
        widget.catagory == "Nike" ||
        widget.catagory == "Others_boot" ||
        widget.catagory == "Adidas") {
      selectedSize = "40";
    } else if (widget.catagory == "Gloves") {
      selectedSize = "9";
    } else if (widget.catagory == "Jersey") {
      selectedSize = "L";
    } else {
      selectedSize = null;
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

  Widget method1() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(6, (index) {
          final size = (39 + index).toString();
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  size,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget method2() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(3, (index) {
          final size = (8 + index).toString();
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  size,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget method3() {
    List<String> sizes = ["M", "L", "XL", "XXL"];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(sizes.length, (index) {
          final size = sizes[index];
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  size,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget method4() {
    return const SizedBox.shrink();
  }

  void _toggleFabMenu() {
    setState(() {
      _isFabMenuOpen = !_isFabMenuOpen;
    });
  }

  void sendMessageToWhatsApp(String number) async {
    final cleanedNumber = number.replaceAll(RegExp(r'[+\s]'), '');
    final sizeInfo = selectedSize != null ? " Size $selectedSize" : "";
    final message = Uri.encodeComponent(
      'Hey I want to order ${widget.title} Price ${widget.price}$sizeInfo Image URL ${widget.image20}',
    );

    final whatsappAppUrl = Uri.parse(
      'whatsapp://send?phone=$cleanedNumber&text=$message',
    );

    final whatsappWebUrl = Uri.parse('https://wa.me/$number?text=$message');

    try {
      if (await canLaunchUrl(whatsappAppUrl)) {
        await launchUrl(whatsappAppUrl);
      } else {
        await launchUrl(whatsappWebUrl);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to open WhatsApp')));
    }
  }

  void _addToCart() async {
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
          String size = selectedSize ?? "no size";

          if (cartItems.containsKey(productId)) {
            if (cartItems[productId] is int) {
              cartItems[productId] = {"default": cartItems[productId]};
            }
          }

          if (cartItems.containsKey(productId)) {
            Map<String, dynamic> sizeMap = cartItems[productId];

            if (sizeMap.containsKey(size)) {
              int currentQty = (sizeMap[size] is int) ? sizeMap[size] : 0;
              sizeMap[size] = currentQty + 1;
            } else {
              sizeMap[size] = 1;
            }
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
          List<CartItem> checkoutItems = [
            CartItem(
              id: widget.productid,
              name: widget.title,
              price: priceValue,
              quantity: 1,
              imageUrl: widget.image5,
              catagory: widget.catagory,
              size: selectedSize ?? "0",
            ),
          ];

          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CheckOut(
                    cartItems: checkoutItems,
                    totalAmount: priceValue,
                  ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
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
              color: Colors.white.withOpacity(0.9),
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
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Image.network(widget.image20, fit: BoxFit.cover),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  fontFamily: 'Georgia',
                                ),
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
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.stars, color: Colors.orange, size: 16),
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
                        Text(
                          widget.price,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle("Availability"),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildFeatureChip(Icons.check_circle_outline, "In Stock"),
                            const SizedBox(width: 10),
                            _buildFeatureChip(Icons.local_shipping_outlined, "Fast Delivery"),
                          ],
                        ),
                        const SizedBox(height: 25),
                        _buildVideoSection(),
                        const SizedBox(height: 25),
                        if (widget.catagory == "Puma" ||
                            widget.catagory == "Nike" ||
                            widget.catagory == "Others_boot" ||
                            widget.catagory == "Adidas")
                          _buildSizeSection(method1())
                        else if (widget.catagory == "Gloves")
                          _buildSizeSection(method2())
                        else if (widget.catagory == "Jersey")
                          _buildSizeSection(method3())
                        else
                          const SizedBox.shrink(),
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

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    return InkWell(
      onTap: () {
        if (widget.videoLink == "No videoLink available") {
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Select Size"),
        const SizedBox(height: 12),
        sizeWidget,
      ],
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Cart())),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _addToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ElevatedButton(
                onPressed: _buyNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Buy Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabMenuOpen) ...[
            _buildContactOption(name: "Rimon", number: "+8801787208108", color: Colors.blue),
            const SizedBox(height: 10),
            _buildContactOption(name: "Rasel", number: "+8801782124891", color: Colors.blueAccent),
            const SizedBox(height: 10),
          ],
          FloatingActionButton(
            onPressed: _toggleFabMenu,
            backgroundColor: Colors.greenAccent,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _isFabMenuOpen ? 0.5 : 0,
              child: const Icon(Icons.message, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption({
    required String name,
    required String number,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        sendMessageToWhatsApp(number);
        _toggleFabMenu();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, color: Colors.white),
            const SizedBox(width: 8),
            Text(name, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
