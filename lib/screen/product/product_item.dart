import 'package:dadu/screen/authentication/sign_up_first.dart';
import 'package:dadu/screen/authentication/sign_up_2nd.dart';
import 'package:dadu/screen/product/product_details.dart';
import 'package:dadu/services/auth.dart';
import 'package:flutter/material.dart';
import '../../services/firebase.dart';

class ProductItem extends StatelessWidget {
  final String productId;
  final String title;
  final String price;
  final String imagePath;
  final String image20;
  final String image5;
  final String description;
  final String videoLink;
  final String brand;
  final dataBase db = dataBase();

  ProductItem({
    super.key,
    required this.productId,
    required this.title,
    required this.price,
    required this.imagePath,
    required this.image20,
    required this.description,
    required this.videoLink,
    required this.brand,
    required this.image5,
  });

  void _addToCart(BuildContext context) async {
    final Auth _auth = Auth();
    final currentUser = _auth.currentUser;

    if (currentUser == null || currentUser.isAnonymous) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SignUpScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create an account to add items to your cart.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Map<String, dynamic>? userDetails = await db.getUserDetails(currentUser.email!);
    String address = userDetails?['address'] ?? '';

    if (address.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SignUpScreen2()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete your profile to add items.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      Map<String, dynamic> cartItems =
          Map<String, dynamic>.from(userDetails?['cart_item'] ?? {});
      const String size = "default"; 

      if (cartItems.containsKey(productId)) {
        var productEntry = cartItems[productId];
        if (productEntry is int) {
          cartItems[productId] = {'default': productEntry + 1};
        } else if (productEntry is Map) {
          int currentQty = (productEntry[size] as int?) ?? 0;
          cartItems[productId][size] = currentQty + 1;
        }
      } else {
        cartItems[productId] = {size: 1};
      }

      await db.updateUserDetails(currentUser.email!, {"cart_item": cartItems});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title added to cart'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        db.incrementClickCount(productId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetails(
              productid: productId,
              title: title,
              price: price,
              image20: image20,
              description: description,
              videoLink: videoLink,
              brand: brand,
              image5: image5,
            ),
          ),
        );
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: Image.network(
                imagePath,
                height: 135,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 140,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 140,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _addToCart(context),
                        icon: Icon(Icons.add_shopping_cart,
                            color: Theme.of(context).primaryColor),iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
