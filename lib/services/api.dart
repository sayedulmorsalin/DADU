import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ImageService {
  // Load credentials from environment variables
  static final String cloudName = dotenv.env['CLOUD_NAME'] ?? '';
  static final String uploadPreset = dotenv.env['UPLOAD_PRESET'] ?? '';
  static final Uri _uploadUrl =
  Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  // Compress profile image
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
      print("Image compression error: $e");
      rethrow;
    }
  }

  // Upload profile image
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
        return data['secure_url']; // Cloudinary hosted URL
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

  // Compress payment image
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
      print("Image compression error: $e");
      rethrow;
    }
  }

  // Upload payment image
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
}
