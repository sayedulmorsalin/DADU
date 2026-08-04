import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';

class ImageService {
  String get _baseUrl {
    String url = dotenv.get('API_BASE_URL', fallback: 'https://api.dadubd.com');
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Uri get _uploadUrl => Uri.parse('$_baseUrl/images/upload');

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

  Future<String?> _getAuthToken() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<String> uploadProfileImage(File image) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception("Unauthorized");

      final compressedBytes = await compressProfileImage(image);

      final request = http.MultipartRequest('POST', _uploadUrl)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['folder'] = 'profile'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          compressedBytes,
          filename: 'profile.jpg',
        ));

      final response = await request.send().timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);
        String rawUrl = data['imageUrl'] ?? '';
        if (rawUrl.startsWith('/')) {
          rawUrl = '$_baseUrl$rawUrl';
        }
        return rawUrl;
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

    try {
      final token = await _getAuthToken();
      if (token == null) return;

      final Uri deleteEndpoint = Uri.parse('$_baseUrl/images');

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
      final token = await _getAuthToken();
      if (token == null) throw Exception("Unauthorized");

      final compressedBytes = await compressPaymentImage(image);

      final request = http.MultipartRequest('POST', _uploadUrl)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['folder'] = 'payments'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          compressedBytes,
          filename: 'payment.jpg',
        ));

      final response = await request.send().timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);
        String rawUrl = data['imageUrl'] ?? '';
        if (rawUrl.startsWith('/')) {
          rawUrl = '$_baseUrl$rawUrl';
        }
        return rawUrl;
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

  Future<Uint8List> compressChatImage(File file) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 60,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );

      if (result == null) throw Exception("Compression returned null");
      return result;
    } catch (e) {
      return await file.readAsBytes();
    }
  }

  Future<String> uploadChatImage(File image) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception("Unauthorized");

      final compressedBytes = await compressChatImage(image);

      final request = http.MultipartRequest('POST', _uploadUrl)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['folder'] = 'chat'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          compressedBytes,
          filename: 'chat_image.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));

      final response = await request.send().timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);
        String rawUrl = data['imageUrl'] ?? '';
        if (rawUrl.startsWith('/')) {
          rawUrl = '$_baseUrl$rawUrl';
        }
        return rawUrl;
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

  /// Uploads multiple files at once to the backend.
  Future<List<String>> uploadMultipleFiles(List<File> files, {String folder = 'chat'}) async {
    if (files.isEmpty) return [];

    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception("Unauthorized");

      final request = http.MultipartRequest('POST', _uploadUrl)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['folder'] = folder;

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final bytes = await compressChatImage(file);
        final filename = file.path.split(Platform.pathSeparator).last;
        
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          bytes,
          filename: filename.endsWith('.jpg') || filename.endsWith('.jpeg') ? filename : '$filename.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final response = await request.send().timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);
        final List<dynamic> fileList = data['files'] ?? [];
        return fileList.map((f) {
          String rawUrl = f['imageUrl'].toString();
          return rawUrl.startsWith('/') ? '$_baseUrl$rawUrl' : rawUrl;
        }).toList();
      } else {
        throw Exception("Multiple upload failed: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Multiple upload error: $e");
    }
  }

  /// Uploads a voice note to the backend.
  Future<String> uploadVoiceNote(File audioFile) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception("Unauthorized");

      final request = http.MultipartRequest('POST', _uploadUrl)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['folder'] = 'voice-notes';

      final bytes = await audioFile.readAsBytes();
      final filename = audioFile.path.split(Platform.pathSeparator).last;
      
      request.files.add(http.MultipartFile.fromBytes(
        'voiceNote',
        bytes,
        filename: filename,
        contentType: MediaType('audio', 'm4a'),
      ));

      final response = await request.send().timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);
        return data['imageUrl']; // The backend uses imageUrl key for voice note as well in single-file response
      } else {
        throw Exception("Voice note upload failed: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Voice note upload error: $e");
    }
  }
}
