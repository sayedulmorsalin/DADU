import 'package:dadu/screen/product/product_details.dart';
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
  final dataBase db = dataBase(); // Database instance

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        db.incrementClickCount(productId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetails(
              productid:productId,
              title: title,
              price: price,
              image20: image20,
              description: description,
              videoLink: videoLink,
              brand: brand, image5: image5,
            ),
          ),
        );
      },
      child: Card(
        elevation: 5,
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
                height: 140,
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
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                      fontSize: 13,
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