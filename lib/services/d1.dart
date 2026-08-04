import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String resolveUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/')) {
      return 'https://api.dadubd.com$path';
    }
    return 'https://api.dadubd.com/$path';
  }

  String get apiBaseUrl {
    String url = dotenv.get('API_BASE_URL', fallback: 'https://api.dadubd.com');
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  String get _baseUrl => apiBaseUrl;

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
    final String cacheKey =
        'products_$limit\_$page\_$category\_$brand\_$search\_$idsKey';

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
          productList = jsonData['data'] ??
              jsonData['products'] ??
              jsonData['items'] ??
              [];
        }

        final results = productList.map((item) {
          return {
            "id": item['id']?.toString() ?? '',
            "name": item['name'] ?? 'No Name',
            "price": item['price']?.toString() ?? '0',
            "details": item['details'] ?? 'No details available',
            "videoLink": item['videoLink'] ?? '',
            "image5": (item['imagePrimary'] != null &&
                    item['imagePrimary'].toString().isNotEmpty)
                ? item['imagePrimary']
                : null,
            "image20": (item['imageOne'] != null &&
                    item['imageOne'].toString().isNotEmpty)
                ? item['imageOne']
                : ((item['imagePrimary'] != null &&
                        item['imagePrimary'].toString().isNotEmpty)
                    ? item['imagePrimary']
                    : null),
            "catagory": item['catagory'] ?? item['brand'] ?? 'Others',
            "gold_coin":
                double.tryParse(item['freeCoin']?.toString() ?? '0') ?? 0.0,
            "createdAt": item['createdAt'],
            "brand": item['brand'] ?? '',
            "imageTwo": item['imageTwo'] ?? '',
            "imageThree": item['imageThree'] ?? '',
            "size": item['size'] ?? '',
            "stock": item['stock'] != null
                ? (int.tryParse(item['stock'].toString()) ?? 1)
                : 1,
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
          "image5": (item['imagePrimary'] != null &&
                  item['imagePrimary'].toString().isNotEmpty)
              ? item['imagePrimary']
              : null,
          "image20": (item['imageOne'] != null &&
                  item['imageOne'].toString().isNotEmpty)
              ? item['imageOne']
              : ((item['imagePrimary'] != null &&
                      item['imagePrimary'].toString().isNotEmpty)
                  ? item['imagePrimary']
                  : null),
          "catagory": item['catagory'] ?? item['brand'] ?? 'Others',
          "gold_coin":
              double.tryParse(item['freeCoin']?.toString() ?? '0') ?? 0.0,
          "brand": item['brand'] ?? '',
          "size": item['size'] ?? '',
          "imageTwo": item['imageTwo'] ?? '',
          "imageThree": item['imageThree'] ?? '',
          "stock": item['stock'] != null
              ? (int.tryParse(item['stock'].toString()) ?? 1)
              : 1,
          "deliveryFee": item['deliveryFee'] ?? '',
          "createdAt": item['createdAt'],
        };

        // Save to cache
        _productDetailsCache[id] = result;
        return result;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Clears all in-memory caches.
  void clearCache() {
    _productsCache.clear();
    _productDetailsCache.clear();
  }

  // --- Messaging Methods ---

  Future<List<Map<String, dynamic>>> fetchMessages(String userId,
      {int limit = 20, int page = 1}) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final String? token = await user.getIdToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/messages/$userId?limit=$limit&page=$page'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          return List<Map<String, dynamic>>.from(jsonData['messages'] ?? []);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> sendMessage(String userId, String message,
      {String? imageUrl, String? voiceNoteUrl, String? replyToId, String? replyToText, String? replyToSenderRole}) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final String? token = await user.getIdToken();
      if (token == null) return false;

      final Map<String, dynamic> body = {
        'userId': userId,
        'message': message,
      };
      if (imageUrl != null) {
        body['imageUrl'] = imageUrl;
      }
      if (voiceNoteUrl != null) {
        body['voiceNoteUrl'] = voiceNoteUrl;
      }
      if (replyToId != null) {
        body['replyToId'] = replyToId;
      }
      if (replyToText != null) {
        body['replyToText'] = replyToText;
      }
      if (replyToSenderRole != null) {
        body['replyToSenderRole'] = replyToSenderRole;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return jsonData['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // --- Review Methods ---

  Future<Map<String, dynamic>?> fetchProductReviews(String productId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/products/$productId/reviews'),
      );
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          return jsonData;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> checkReviewEligibility(String productId) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'eligible': false, 'reason': 'Please log in to review this product'};
      }
      final String? token = await user.getIdToken();
      if (token == null) {
        return {'eligible': false, 'reason': 'Authentication token invalid'};
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/products/$productId/review-eligibility'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          return jsonData;
        }
      }
      return {'eligible': false, 'reason': 'Could not verify review eligibility'};
    } catch (e) {
      return {'eligible': false, 'reason': 'Error checking eligibility: $e'};
    }
  }

  Future<String?> uploadReviewImage(File imageFile) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final String? token = await user.getIdToken();
      if (token == null) return null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/upload/review-image'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          return jsonData['imageUrl'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> submitProductReview(
    String productId, {
    required int rating,
    required String comment,
    String? imageUrl,
    String? userName,
  }) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }
      final String? token = await user.getIdToken();
      if (token == null) {
        return {'success': false, 'error': 'Token invalid'};
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/products/$productId/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'rating': rating,
          'comment': comment,
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (userName != null) 'userName': userName,
        }),
      );

      final jsonData = jsonDecode(response.body);
      return jsonData;
    } catch (e) {
      return {'success': false, 'error': 'Failed to submit review: $e'};
    }
  }
}
