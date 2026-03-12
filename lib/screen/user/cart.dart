import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/screen/user/check_out.dart';
import 'package:dadu/services/auth.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
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
  final dataBase db = dataBase();
  Future<List<CartItem>>? _cartItemsFuture;
  String? _lastCartSignature;

  Future<List<CartItem>> _processCartData(Map<String, dynamic> cartData) async {
    List<CartItem> loadedCartItems = [];

    for (var entry in cartData.entries) {
      final productId = entry.key;
      final value = entry.value;

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
              size: "default",
            ),
          );
        }
      } else if (value is Map<String, dynamic>) {
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
    return loadedCartItems;
  }

  String _buildCartSignature(Map<String, dynamic> cartData) {
    dynamic normalize(dynamic value) {
      if (value is Map) {
        final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
        return {for (final key in sortedKeys) key: normalize(value[key])};
      }
      if (value is List) {
        return value.map(normalize).toList();
      }
      return value;
    }

    return jsonEncode(normalize(cartData));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    if (currentUser == null || currentUser.isAnonymous) {
      return _buildLoggedOutView();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.getUserStream(currentUser.email!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("User not found."));
        }

        final userDetails = snapshot.data!.data();
        final cartData =
            userDetails?['cart_item'] as Map<String, dynamic>? ?? {};
        final cartSignature = _buildCartSignature(cartData);

        if (userDetails?['address'] == null ||
            userDetails!['address'].isEmpty) {
          return _buildProfileCompletionView();
        }

        if (_cartItemsFuture == null || _lastCartSignature != cartSignature) {
          _lastCartSignature = cartSignature;
          _cartItemsFuture = _processCartData(cartData);
        }

        return FutureBuilder<List<CartItem>>(
          future: _cartItemsFuture,
          builder: (context, cartSnapshot) {
            if (cartSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (cartSnapshot.hasError) {
              return Center(child: Text("Error: ${cartSnapshot.error}"));
            }

            final cartItems = cartSnapshot.data ?? [];

            return _buildCartView(cartItems);
          },
        );
      },
    );
  }

  Widget _buildLoggedOutView() {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Please log in to view your cart.'),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpScreen()),
                );
              },
              child: const Text('Log In / Sign Up'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCompletionView() {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Please complete your profile to use the cart.'),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpScreen2()),
                );
              },
              child: const Text('Complete Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartView(List<CartItem> cartItems) {
    double totalAmount = cartItems.fold(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    ); // Calculate total amount

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Your Cart',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _clearCart(cartItems),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                cartItems.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 80,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Your cart is empty',
                            style: TextStyle(
                              fontSize: 20,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: cartItems.length,
                      itemBuilder: (ctx, index) {
                        final item = cartItems[index];
                        return Dismissible(
                          key: ValueKey('${item.id}_${item.size}'),
                          background: Container(
                            color: AppColors.error,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                          direction: DismissDirection.endToStart,
                          onDismissed:
                              (direction) =>
                                  _removeItem(item.id, item.size, cartItems),
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
                                        if (item.size != "default")
                                          Text(
                                            'Size: ${item.size}',
                                            style: TextStyle(
                                              color: AppColors.textMuted,
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
                                        onPressed:
                                            () => _decreaseQuantity(
                                              item.id,
                                              item.size,
                                              cartItems,
                                            ),
                                      ),
                                      Text(
                                        item.quantity.toString(),
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed:
                                            () => _increaseQuantity(
                                              item.id,
                                              item.size,
                                              cartItems,
                                            ),
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
                    '\৳${totalAmount.toStringAsFixed(2)}',
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
                      builder:
                          (context) => CheckOut(
                            cartItems: cartItems,
                            totalAmount: totalAmount,
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
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateCartInFirestore(List<CartItem> cartItems) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.email == null) {
      throw Exception("User not authenticated");
    }

    final Map<String, dynamic> newCartMap = {};
    for (final item in cartItems) {
      if (!newCartMap.containsKey(item.id)) {
        newCartMap[item.id] = <String, int>{};
      }
      (newCartMap[item.id] as Map<String, int>)[item.size] = item.quantity;
    }

    final success = await db.updateUserDetails(currentUser.email!, {
      'cart_item': newCartMap,
    });

    if (!success) throw Exception("Firestore update failed");
  }

  void _increaseQuantity(
    String id,
    String size,
    List<CartItem> currentItems,
  ) async {
    List<CartItem> updatedItems = List.from(currentItems);
    final item = updatedItems.firstWhere((i) => i.id == id && i.size == size);
    item.quantity++;
    await _updateCartInFirestore(updatedItems);
  }

  void _decreaseQuantity(
    String id,
    String size,
    List<CartItem> currentItems,
  ) async {
    List<CartItem> updatedItems = List.from(currentItems);
    final item = updatedItems.firstWhere((i) => i.id == id && i.size == size);
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      updatedItems.remove(item);
    }
    await _updateCartInFirestore(updatedItems);
  }

  void _removeItem(String id, String size, List<CartItem> currentItems) async {
    List<CartItem> updatedItems = List.from(currentItems);
    updatedItems.removeWhere((item) => item.id == id && item.size == size);
    await _updateCartInFirestore(updatedItems);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item removed'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _clearCart(List<CartItem> currentItems) async {
    await _updateCartInFirestore([]);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cart cleared'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}
