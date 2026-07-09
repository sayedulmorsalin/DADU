import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static const String _baseUrl = 'https://api.dadubd.com';

  /// Fetches products from the API and maps them to the app's internal format.
  /// Based on the provided products table schema.
  Future<List<Map<String, dynamic>>> fetchProducts({
    int limit = 20,
    int page = 1,
    String? category,
    String? brand,
    String? search,
  }) async {
    try {
      // 1. Get the current authenticated user
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User is not authenticated');
      }

      // 2. Retrieve the ID token (JWT)
      final String? token = await user.getIdToken();
      if (token == null) {
        throw Exception('Failed to get auth token');
      }

      // 3. Perform GET request with Authorization header and pagination parameters
      String url = '$_baseUrl/products?limit=$limit&page=$page';
      if (category != null) {
        url += '&catagory=${Uri.encodeComponent(category)}';
      }
      if (brand != null) {
        url += '&brand=${Uri.encodeComponent(brand)}';
      }
      if (search != null) {
        url += '&q=${Uri.encodeComponent(search)}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        List<dynamic> productList = [];

        if (jsonData is List) {
          productList = jsonData;
        } else if (jsonData is Map) {
          productList = jsonData['data'] ?? jsonData['products'] ?? jsonData['items'] ?? [];
        }

        // 4. Map API response to internal product format expected by the UI
        return productList.map((item) {
          return {
            // Core fields used by ProductItem and ProductDetails
            "id": item['id']?.toString() ?? '',
            "name": item['name'] ?? 'No Name',
            "price": item['price']?.toString() ?? '0',
            "details": item['details'] ?? 'No details available',
            "videoLink": item['videoLink'] ?? '',
            "image5": (item['imagePrimary'] != null && item['imagePrimary'].toString().isNotEmpty) ? item['imagePrimary'] : null,
            "image20": (item['imageOne'] != null && item['imageOne'].toString().isNotEmpty) ? item['imageOne'] : ((item['imagePrimary'] != null && item['imagePrimary'].toString().isNotEmpty) ? item['imagePrimary'] : null),
            "catagory": item['catagory'] ?? item['brand'] ?? 'Others',
            "gold_coin": (item['freeCoin'] as num?)?.toDouble() ?? 0.0,
            "createdAt": item['createdAt'],

            // Additional fields from the API schema
            "brand": item['brand'] ?? '',
            "imageTwo": item['imageTwo'] ?? '',
            "imageThree": item['imageThree'] ?? '',
            "size": item['size'] ?? '',
            "stock": item['stock'] ?? 0,
            "deliveryFee": item['deliveryFee'] ?? '',
          };
        }).toList();
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      print('ApiService fetchProducts Error: $e');
      return []; // Return empty list on error to prevent UI crash
    }
  }

  Future<Map<String, dynamic>?> fetchProductById(String id) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final String? token = await user.getIdToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/products/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        final item = jsonData['product'];
        if (item == null) return null;

        return {
          "id": item['id']?.toString() ?? '',
          "name": item['name'] ?? 'No Name',
          "price": item['price']?.toString() ?? '0',
          "details": item['details'] ?? 'No details available',
          "videoLink": item['videoLink'] ?? '',
          "image5": (item['imagePrimary'] != null && item['imagePrimary'].toString().isNotEmpty) ? item['imagePrimary'] : null,
          "image20": (item['imageOne'] != null && item['imageOne'].toString().isNotEmpty) ? item['imageOne'] : ((item['imagePrimary'] != null && item['imagePrimary'].toString().isNotEmpty) ? item['imagePrimary'] : null),
          "catagory": item['catagory'] ?? item['brand'] ?? 'Others',
          "gold_coin": (item['freeCoin'] as num?)?.toDouble() ?? 0.0,
          "brand": item['brand'] ?? '',
          "size": item['size'] ?? '',
          "imageTwo": item['imageTwo'] ?? '',
          "imageThree": item['imageThree'] ?? '',
          "stock": item['stock'] ?? 0,
          "deliveryFee": item['deliveryFee'] ?? '',
          "createdAt": item['createdAt'],
        };
      }
      return null;
    } catch (e) {
      print('ApiService fetchProductById Error: $e');
      return null;
    }
  }
}
