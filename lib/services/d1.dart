import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static const String _baseUrl = 'https://api.dadubd.com';

  // In-memory cache to reduce network requests
  final Map<String, List<Map<String, dynamic>>> _productsCache = {};
  final Map<String, Map<String, dynamic>> _productDetailsCache = {};

  /// Fetches products from the API and maps them to the app's internal format.
  Future<List<Map<String, dynamic>>> fetchProducts({
    int limit = 20,
    int page = 1,
    String? category,
    String? brand,
    String? search,
    List<String>? ids,
  }) async {
    final String idsKey = ids != null ? ids.join(',') : '';
    final String cacheKey = 'products_$limit\_$page\_$category\_$brand\_$search\_$idsKey';
    
    // Return from cache if available
    if (_productsCache.containsKey(cacheKey)) {
      return _productsCache[cacheKey]!;
    }

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User is not authenticated');
      }

      final String? token = await user.getIdToken();
      if (token == null) {
        throw Exception('Failed to get auth token');
      }

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
      if (ids != null && ids.isNotEmpty) {
        url += '&ids=${Uri.encodeComponent(ids.join(','))}';
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

        final results = productList.map((item) {
          return {
            "id": item['id']?.toString() ?? '',
            "name": item['name'] ?? 'No Name',
            "price": item['price']?.toString() ?? '0',
            "details": item['details'] ?? 'No details available',
            "videoLink": item['videoLink'] ?? '',
            "image5": (item['imagePrimary'] != null && item['imagePrimary'].toString().isNotEmpty) ? item['imagePrimary'] : null,
            "image20": (item['imageOne'] != null && item['imageOne'].toString().isNotEmpty) ? item['imageOne'] : ((item['imagePrimary'] != null && item['imagePrimary'].toString().isNotEmpty) ? item['imagePrimary'] : null),
            "catagory": item['catagory'] ?? item['brand'] ?? 'Others',
            "gold_coin": double.tryParse(item['freeCoin']?.toString() ?? '0') ?? 0.0,
            "createdAt": item['createdAt'],
            "brand": item['brand'] ?? '',
            "imageTwo": item['imageTwo'] ?? '',
            "imageThree": item['imageThree'] ?? '',
            "size": item['size'] ?? '',
            "stock": item['stock'] != null ? (int.tryParse(item['stock'].toString()) ?? 1) : null,
            "deliveryFee": item['deliveryFee'] ?? '',
          };
        }).toList();

        // Save to cache
        _productsCache[cacheKey] = results;
        return results;
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      print('ApiService fetchProducts Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchProductById(String id) async {
    // Return from cache if available
    if (_productDetailsCache.containsKey(id)) {
      return _productDetailsCache[id];
    }

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

        final result = {
          "id": item['id']?.toString() ?? '',
          "name": item['name'] ?? 'No Name',
          "price": item['price']?.toString() ?? '0',
          "details": item['details'] ?? 'No details available',
          "videoLink": item['videoLink'] ?? '',
          "image5": (item['imagePrimary'] != null && item['imagePrimary'].toString().isNotEmpty) ? item['imagePrimary'] : null,
          "image20": (item['imageOne'] != null && item['imageOne'].toString().isNotEmpty) ? item['imageOne'] : ((item['imagePrimary'] != null && item['imagePrimary'].toString().isNotEmpty) ? item['imagePrimary'] : null),
          "catagory": item['catagory'] ?? item['brand'] ?? 'Others',
          "gold_coin": double.tryParse(item['freeCoin']?.toString() ?? '0') ?? 0.0,
          "brand": item['brand'] ?? '',
          "size": item['size'] ?? '',
          "imageTwo": item['imageTwo'] ?? '',
          "imageThree": item['imageThree'] ?? '',
          "stock": item['stock'] != null ? (int.tryParse(item['stock'].toString()) ?? 1) : null,
          "deliveryFee": item['deliveryFee'] ?? '',
          "createdAt": item['createdAt'],
        };

        // Save to cache
        _productDetailsCache[id] = result;
        return result;
      }
      return null;
    } catch (e) {
      print('ApiService fetchProductById Error: $e');
      return null;
    }
  }

  /// Clears all in-memory caches.
  void clearCache() {
    _productsCache.clear();
    _productDetailsCache.clear();
  }
}
