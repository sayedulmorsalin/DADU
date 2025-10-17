import 'package:dadu/screen/user/cart.dart';
import 'package:dadu/screen/user/check_out.dart';
import 'package:dadu/services/auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  final String brand;
  final String productid;

  const ProductDetails({
    super.key,
    required this.title,
    required this.price,
    required this.image20,
    required this.description,
    required this.videoLink,
    required this.brand,
    required this.productid,
    required this.image5,
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
    // Set default size based on brand
    if (widget.brand == "Puma" ||
        widget.brand == "Nike" ||
        widget.brand == "Others_boot" ||
        widget.brand == "Adidas") {
      selectedSize = "40";
    } else if (widget.brand == "Gloves") {
      selectedSize = "9";
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

  Widget method1() {
    return Row(
      children: [
        const Text(
          "Size: ",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        ...List.generate(6, (index) {
          final size = (39 + index).toString();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedSize = size;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selectedSize == size ? Colors.green : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  size,
                  style: TextStyle(
                    color: selectedSize == size ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget method2() {
    return Row(
      children: [
        const Text(
          "Size: ",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        ...List.generate(4, (index) {
          final size = (7 + index).toString();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedSize = size;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selectedSize == size ? Colors.green : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  size,
                  style: TextStyle(
                    color: selectedSize == size ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget method3() {
    return const SizedBox.shrink();
  }

  void _toggleFabMenu() {
    setState(() {
      _isFabMenuOpen = !_isFabMenuOpen;
    });
  }

  void sendMessageToWhatsApp(String number) async {
    // Remove '+' and whitespace for WhatsApp URI scheme
    final cleanedNumber = number.replaceAll(RegExp(r'[+\s]'), '');
    final sizeInfo = selectedSize != null ? " Size $selectedSize" : "";
    final message = Uri.encodeComponent(
      'Hey I want to order ${widget.title} Price ${widget.price}$sizeInfo Image URL ${widget.image20}',
    );

    // WhatsApp app URL
    final whatsappAppUrl = Uri.parse(
      'whatsapp://send?phone=$cleanedNumber&text=$message',
    );
    // Web fallback URL
    final whatsappWebUrl = Uri.parse('https://wa.me/$number?text=$message');

    try {
      if (await canLaunchUrl(whatsappAppUrl)) {
        await launchUrl(whatsappAppUrl);
      } else {
        debugPrint("WhatsApp app not installed, using web fallback");
        await launchUrl(whatsappWebUrl);
      }
    } catch (e) {
      debugPrint('Could not launch WhatsApp: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to open WhatsApp')));
    }
  }

  // Add to Cart functionality
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
          String size = selectedSize??"no size"; // Your selected size (e.g., "M", "L")

          // 1. Handle old cart format (int quantity) if exists for this product
          if (cartItems.containsKey(productId)) {
            if (cartItems[productId] is int) {
              // Convert old format to new size-based format
              cartItems[productId] = {"default": cartItems[productId]};
            }
          }

          // 2. Process size-based cart logic
          if (cartItems.containsKey(productId)) {
            // Get size map (guaranteed to be Map after conversion above)
            Map<String, dynamic> sizeMap = cartItems[productId];

            // 2a. SAME SIZE EXISTS: Increment quantity
            if (sizeMap.containsKey(size)) {
              int currentQty = (sizeMap[size] is int) ? sizeMap[size] : 0;
              sizeMap[size] = currentQty + 1;
            }
            // 2b. DIFFERENT SIZE: Add new size entry
            else {
              sizeMap[size] = 1;
            }
          }
          // 2c. NEW PRODUCT: Create size map
          else {
            cartItems[productId] = {size: 1};
          }

          // 3. Update cart
          await db.updateUserDetails(currentUser.email!, {"cart_item": cartItems});

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
    // Remove all non-digit characters except decimal point
    String cleaned = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  // Buy Now functionality
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
              brand: widget.brand,
              size: selectedSize??"0",
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
      backgroundColor: const Color(0xFFf2f2ce),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Main content with bottom padding for buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 80.0),
            child: ListView(
              children: [
                Container(
                  height: 400,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    child: Image.network(widget.image20, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        widget.price,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 4,
                        ),
                        onPressed: () {
                          if (widget.videoLink == "No videoLink available") {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Video is not available now, it will be added soon'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } else {
                            _launchURL(widget.videoLink);
                          }

                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.facebook,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const FaIcon(
                              FontAwesomeIcons.youtube,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const FaIcon(
                              FontAwesomeIcons.tiktok,
                              color: Colors.black,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Watch Video For more info",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (widget.brand == "Puma" ||
                          widget.brand == "Nike" ||
                          widget.brand == "Others_boot" ||
                          widget.brand == "Adidas")
                        method1()
                      else if (widget.brand == "Gloves")
                        method2()
                      else
                        method3(),
                      SizedBox(height: 180),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Add to Cart and Buy Now buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Add to Cart button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => Cart()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'View Cart',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Buy Now button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _buyNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Buy Now',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Action Button with menu - positioned above bottom bar
          Positioned(
            bottom: 90, // Positioned above the bottom button bar
            right: 16,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedOpacity(
                  opacity: _isFabMenuOpen ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      children: [
                        _buildContactOption(
                          name: "Rimon",
                          number: "+8801787208108",
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 10),
                        _buildContactOption(
                          name: "Rasel",
                          number: "+8801782124891",
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                  ),
                ),
                FloatingActionButton(
                  onPressed: _toggleFabMenu,
                  backgroundColor: Colors.greenAccent,
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isFabMenuOpen ? 0.5 : 0,
                    child: const Icon(Icons.message),
                  ),
                ),
              ],
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
