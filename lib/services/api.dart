import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ImageService {

  static final String cloudName = dotenv.env['CLOUD_NAME'] ?? '';
  static final String uploadPreset = dotenv.env['UPLOAD_PRESET'] ?? '';
  static final String apiKey = dotenv.env['API_KEY'] ?? '';
  static final String apiSecret = dotenv.env['API_SECRET'] ?? '';
  static final Uri _uploadUrl =
  Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
  static final Uri _deleteUrl =
  Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');


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
      if (apiKey.isEmpty || apiSecret.isEmpty) {
        print("Cloudinary API credentials missing. Deletion skipped.");
        return;
      }

      // Extract public_id from URL
      // Example: https://res.cloudinary.com/demo/image/upload/v1571218039/sample.jpg
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isEmpty) return;

      // The public_id is usually the last segment without extension
      String publicIdWithExt = pathSegments.last;
      String publicId = publicIdWithExt.split('.').first;

      // Handle folders if present (segments after 'upload/' or version 'vXXXX/')
      int uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex != -1 && pathSegments.length > uploadIndex + 1) {
        // Skip 'upload' and potentially 'vXXXX'
        int startIndex = uploadIndex + 1;
        if (pathSegments[startIndex].startsWith('v') && pathSegments[startIndex].length > 1) {
          startIndex++;
        }
        if (startIndex < pathSegments.length - 1) {
          publicId = pathSegments.sublist(startIndex, pathSegments.length - 1).join('/') + '/' + publicId;
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signatureData = "public_id=$publicId&timestamp=$timestamp$apiSecret";
      final signature = sha1.convert(utf8.encode(signatureData)).toString();

      final response = await http.post(
        _deleteUrl,
        body: {
          'public_id': publicId,
          'timestamp': timestamp.toString(),
          'api_key': apiKey,
          'signature': signature,
        },
      );

      if (response.statusCode == 200) {
        print("Image deleted successfully: $publicId");
      } else {
        print("Failed to delete image: ${response.body}");
      }
    } catch (e) {
      print("Error deleting image: $e");
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
}
