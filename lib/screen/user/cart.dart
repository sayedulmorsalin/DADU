import 'package:dadu/screen/user/check_out.dart';
import 'package:dadu/services/auth.dart';
import 'package:flutter/material.dart';
import '../../model/cart_model.dart';
import '../../services/firebase.dart';
import '../authentication/sign_up_2nd.dart';
import '../authentication/sign_up_first.dart';

class Cart extends StatefulWidget {
  const Cart({super.key});

  @override
  State<Cart> createState() => _CartState();
}

class _CartState extends State<Cart> {
  final Auth _auth = Auth();
  String Address = "";
  String productId = "";
  int productCount = 0;
  String brand = '';
  final dataBase db = new dataBase();

  void initState() {
    super.initState();
    _loadCartData();
  }

  List<CartItem> cartItems = [];

  Future<void> _loadCartData() async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have an account please create one'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => SignUpScreen()),
          );
        }
        return;
      }

      if (currentUser.isAnonymous) {
        if (mounted) {
          Navigator.pop(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => SignUpScreen()),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have an account please create one'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complete your profile'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      /// ✅ Start processing cart with size support
      final cartItem = userDetails?['cart_item'];
      List<CartItem> loadedCartItems = [];

      if (cartItem != null && cartItem is Map<String, dynamic>) {
        for (var entry in cartItem.entries) {
          final productId = entry.key;
          final value = entry.value;

          // Handle old cart format (int quantity)
          if (value is int) {
            final productData = await db.getProductById(productId);
            if (productData != null) {
              loadedCartItems.add(
                CartItem(
                  id: productId,
                  name: productData['name'] ?? 'Unknown',
                  price: double.tryParse(productData['price'].toString()) ?? 0.0,
                  quantity: value,
                  imageUrl: productData['image5'] ?? '',
                  brand: productData['brand'],
                  size: "default", // Migrate old items to "default" size
                ),
              );
            }
          }
          // Handle new cart format (size map)
          else if (value is Map<String, dynamic>) {
            for (var sizeEntry in value.entries) {
              String size = sizeEntry.key;
              int quantity = sizeEntry.value as int;

              final productData = await db.getProductById(productId);
              if (productData != null) {
                loadedCartItems.add(
                  CartItem(
                    id: productId,
                    name: productData['name'] ?? 'Unknown',
                    price: double.tryParse(productData['price'].toString()) ?? 0.0,
                    quantity: quantity,
                    imageUrl: productData['image5'] ?? '',
                    brand: productData['brand'],
                    size: size,
                  ),
                );
              }
            }
          }
        }
      } else {
        print('No cart items found or wrong format.');
      }

      // Update UI state
      if (mounted) {
        setState(() {
          cartItems = loadedCartItems;
        });
      }
    } catch (e) {
      print("Error loading cart: $e");
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading Cart: $e")));
      }
    }
  }

  // Clone cart items for state restoration on failure
  List<CartItem> _cloneCartItems() {
    return cartItems
        .map(
          (item) => CartItem(
        id: item.id,
        name: item.name,
        price: item.price,
        quantity: item.quantity,
        imageUrl: item.imageUrl,
        brand: item.brand,
        size: item.size,
      ),
    )
        .toList();
  }

  // Update Firestore cart with current items (size-aware)
  Future<void> _updateCartInFirestore() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.email == null) {
      throw Exception("User not authenticated");
    }

    // Convert cart items to Firestore map format (size-aware)
    final Map<String, dynamic> newCartMap = {};
    for (final item in cartItems) {
      // Initialize product entry if not exists
      if (!newCartMap.containsKey(item.id)) {
        newCartMap[item.id] = <String, int>{};
      }
      // Add/update size quantity
      (newCartMap[item.id] as Map<String, int>)[item.size] = item.quantity;
    }

    // Update Firestore
    final success = await db.updateUserDetails(currentUser.email!, {
      'cart_item': newCartMap,
    });

    if (!success) throw Exception("Firestore update failed");
  }

  // Size-aware quantity update methods
  void _increaseQuantity(String id, String size) async {
    final oldCartItems = _cloneCartItems();

    setState(() {
      final item = cartItems.firstWhere((i) => i.id == id && i.size == size);
      item.quantity++;
    });

    try {
      await _updateCartInFirestore();
    } catch (e) {
      setState(() => cartItems = oldCartItems);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Update failed: ${e.toString()}")));
    }
  }

  void _decreaseQuantity(String id, String size) async {
    final oldCartItems = _cloneCartItems();
    bool removed = false;

    setState(() {
      final item = cartItems.firstWhere((i) => i.id == id && i.size == size);
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        cartItems.remove(item);
        removed = true;
      }
    });

    try {
      await _updateCartInFirestore();
      if (removed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item removed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() => cartItems = oldCartItems);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Update failed: ${e.toString()}")));
    }
  }

  void _removeItem(String id, String size) async {
    final oldCartItems = _cloneCartItems();

    setState(() {
      cartItems.removeWhere((item) => item.id == id && item.size == size);
    });

    try {
      await _updateCartInFirestore();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item removed'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      setState(() => cartItems = oldCartItems);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Removal failed: ${e.toString()}")),
      );
    }
  }

  double get _totalAmount {
    return cartItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf2f2ce),
      appBar: AppBar(
        title: const Text('Your Cart', style: TextStyle(fontWeight: FontWeight.bold),),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final oldCartItems = _cloneCartItems();

              setState(() => cartItems.clear());

              try {
                await _updateCartInFirestore();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cart cleared'),
                    duration: Duration(seconds: 1),
                  ),
                );
              } catch (e) {
                setState(() => cartItems = oldCartItems);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Clear failed: ${e.toString()}")),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: cartItems.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (ctx, index) {
                final item = cartItems[index];
                return Dismissible(
                  key: ValueKey('${item.id}_${item.size}'), // Unique key for size
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) =>
                      _removeItem(item.id, item.size),
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.imageUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Show size if not default
                                if (item.size != "default")
                                  Text(
                                    'Size: ${item.size}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  '\৳${item.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color:
                                    Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () =>
                                    _decreaseQuantity(item.id, item.size),
                              ),
                              Text(
                                item.quantity.toString(),
                                style: const TextStyle(fontSize: 18),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () =>
                                    _increaseQuantity(item.id, item.size),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (cartItems.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\৳${_totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 24,
                top: 8,
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckOut(
                        cartItems: cartItems,
                        totalAmount: _totalAmount,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'CHECKOUT',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}