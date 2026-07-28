import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ImageService {

  static final String cloudName = dotenv.env['CLOUD_NAME'] ?? '';
  static final String uploadPreset = dotenv.env['UPLOAD_PRESET'] ?? '';
  static final String apiKey = dotenv.env['API_KEY'] ?? '';
  static final String apiSecret = dotenv.env['API_SECRET'] ?? '';
  static final Uri _uploadUrl =
  Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  Future<Uint8List> compressProfileImage(File file) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 800,
        minHeight: 800,
        quality: 20,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );

      if (result == null) throw Exception("Compression returned null");
      return result;
    } catch (e) {
      rethrow;
    }
  }


  Future<String> uploadProfileImage(File image) async {
    try {
      final compressedBytes = await compressProfileImage(image);

      final request = http.MultipartRequest('POST', _uploadUrl)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', compressedBytes,
            filename: 'profile.jpg'));

      final response = await request.send().timeout(
          const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);
        return data['secure_url'];
      } else {
        throw Exception("Upload failed: ${response.statusCode}");
      }
    } on TimeoutException {
      throw Exception("Upload timed out");
    } on SocketException {
      throw Exception("No internet connection");
    } catch (e) {
      throw Exception("Upload error: $e");
    }
  }

  Future<void> deleteImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;
    if (!imageUrl.contains('cloudinary.com')) return;

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      final String? token = await user.getIdToken();
      if (token == null) {
        return;
      }

      final String baseUrl = dotenv.get('API_BASE_URL', fallback: 'https://api.dadubd.com');
      final Uri deleteEndpoint = Uri.parse('$baseUrl/images');

      final response = await http.delete(
        deleteEndpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'imageUrl': imageUrl}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Image deleted successfully
      } else {
        // Failed to delete image
      }
    } catch (e) {
      // Error deleting image
    }
  }


  Future<Uint8List> compressPaymentImage(File file) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 800,
        minHeight: 800,
        quality: 50,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );

      if (result == null) throw Exception("Compression returned null");
      return result;
    } catch (e) {
      rethrow;
    }
  }


  Future<String> uploadPaymentImage(File image) async {
    try {
      final compressedBytes = await compressPaymentImage(image);

      final request = http.MultipartRequest('POST', _uploadUrl)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', compressedBytes,
            filename: 'payment.jpg'));

      final response = await request.send().timeout(
          const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);
        return data['secure_url'];
      } else {
        throw Exception("Upload failed: ${response.statusCode}");
      }
    } on TimeoutException {
      throw Exception("Upload timed out");
    } on SocketException {
      throw Exception("No internet connection");
    } catch (e) {
      throw Exception("Upload error: $e");
    }
  }

  Future<String> uploadChatImage(File image) async {
    try {
      // Reusing payment compression or we can define a chat-specific one
      final compressedBytes = await compressPaymentImage(image);

      final request = http.MultipartRequest('POST', _uploadUrl)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', compressedBytes,
            filename: 'chat_image.jpg'));

      final response = await request.send().timeout(
          const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);
        return data['secure_url'];
      } else {
        throw Exception("Upload failed: ${response.statusCode}");
      }
    } on TimeoutException {
      throw Exception("Upload timed out");
    } on SocketException {
      throw Exception("No internet connection");
    } catch (e) {
      throw Exception("Upload error: $e");
    }
  }
}
