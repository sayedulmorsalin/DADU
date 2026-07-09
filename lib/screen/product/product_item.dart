import 'package:cached_network_image/cached_network_image.dart';
import 'package:dadu/screen/authentication/sign_up_first.dart';
import 'package:dadu/screen/authentication/sign_up_2nd.dart';
import 'package:dadu/screen/product/product_details.dart';
import 'package:dadu/services/auth.dart';
import 'package:dadu/theme/app_colors.dart';
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
  final String catagory;
  final double goldCoin;
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
    required this.catagory,
    required this.image5,
    this.goldCoin = 0.0,
  });

  void _addToCart(BuildContext context) async {
    final Auth auth = Auth();
    final currentUser = auth.currentUser;

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

    final userDetails = await db.getUserDetails(currentUser.email!);
    final address = userDetails?['address']?.toString() ?? '';

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
      final cartItems = Map<String, dynamic>.from(
        userDetails?['cart_item'] ?? {},
      );
      const size = 'default';

      if (cartItems.containsKey(productId)) {
        final productEntry = cartItems[productId];
        if (productEntry is int) {
          cartItems[productId] = {'default': productEntry + 1};
        } else if (productEntry is Map) {
          final currentQty = (productEntry[size] as int?) ?? 0;
          cartItems[productId][size] = currentQty + 1;
        }
      } else {
        cartItems[productId] = {size: 1};
      }

      await db.updateUserDetails(currentUser.email!, {'cart_item': cartItems});

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
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildImage(String path) {
    if (path.isEmpty) {
      return Container(
        height: 135,
        color: AppColors.placeholderBackground,
        child: const Icon(Icons.image_not_supported),
      );
    }

    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        height: 135,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder:
            (_, __) => Container(
              height: 135,
              alignment: Alignment.center,
              color: AppColors.placeholderBackground,
              child: const CircularProgressIndicator(),
            ),
        errorWidget:
            (_, __, ___) => Container(
              height: 135,
              color: AppColors.placeholderBackground,
              child: const Icon(Icons.broken_image),
            ),
      );
    } else {
      return Image.asset(
        path,
        height: 135,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 135,
            color: AppColors.placeholderBackground,
            child: const Icon(Icons.broken_image),
          );
        },
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
            builder:
                (context) => ProductDetails(
                  productid: productId,
                  title: title,
                  price: price,
                  image20: image20,
                  description: description,
                  videoLink: videoLink,
                  catagory: catagory,
                  image5: image5,
                  goldCoin: goldCoin,
                ),
          ),
        );
      },
      child: Card(
        color: AppColors.cardBackground,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: _buildImage(imagePath),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 15,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Cash back ${goldCoin.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _addToCart(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_shopping_cart,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Add to Cart',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
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
