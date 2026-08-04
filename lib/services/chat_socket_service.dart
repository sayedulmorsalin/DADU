import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class ChatSocketService extends GetxService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  final RxBool isConnected = false.obs;
  final RxBool isTyping = false.obs;
  
  Timer? _reconnectTimer;
  String? _currentUserId;

  void connect(String userId) {
    if (_currentUserId == userId && isConnected.value) return;
    _currentUserId = userId;
    
    _disconnect();
    _establishConnection();
  }

  Future<void> _establishConnection() async {
    if (_currentUserId == null) return;

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String? token = await user.getIdToken();
      if (token == null) return;

      String configuredBase = dotenv.get('API_BASE_URL', fallback: 'https://api.dadubd.com');
      List<String> candidateBases = [
        configuredBase,
        'https://my-api.sayadulmorsalin123.workers.dev',
        'https://api.dadubd.com',
      ].toSet().toList();

      bool connected = false;

      for (String baseUrl in candidateBases) {
        try {
          String wsUrl = baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
          if (wsUrl.endsWith('/')) {
            wsUrl = wsUrl.substring(0, wsUrl.length - 1);
          }
          final uri = Uri.parse('$wsUrl/ws/$_currentUserId');

          final channel = IOWebSocketChannel.connect(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
            },
            pingInterval: const Duration(seconds: 20),
          );

          // Await ready with timeout to catch host lookup errors gracefully
          await channel.ready.timeout(const Duration(seconds: 4));

          _channel = channel;
          isConnected.value = true;
          connected = true;
          _listen();
          break;
        } catch (e) {
          // Connection failed
        }
      }

      if (!connected) {
        isConnected.value = false;
        _scheduleReconnect();
      }
    } catch (e) {
      isConnected.value = false;
      _scheduleReconnect();
    }
  }

  void _listen() {
    _channel?.stream.listen(
      (data) {
        try {
          final Map<String, dynamic> event = jsonDecode(data);
          
          if (event['type'] == 'new_message') {
            // Map the event to the app's message format if necessary
            // The backend returns: { type, id, userId, senderRole, message, imageUrl, voiceNoteUrl, createdAt }
            _messageController.add(event);
          } else if (event['type'] == 'typing') {
            if (event['senderRole'] == 'admin') {
              isTyping.value = true;
            }
          } else if (event['type'] == 'stop_typing') {
            if (event['senderRole'] == 'admin') {
              isTyping.value = false;
            }
          } else if (event['type'] == 'error') {
            Get.snackbar('Chat Error', event['error'] ?? 'Unknown error');
          }
        } catch (e) {
          // Decode error
        }
      },
      onDone: () {
        isConnected.value = false;
        _scheduleReconnect();
      },
      onError: (error) {
        // Catch DNS/socket errors here to prevent Unhandled Exception crashes
        isConnected.value = false;
        _scheduleReconnect();
      },
      cancelOnError: true,
    );
  }

  void sendMessage(String message, {String? imageUrl, String? voiceNoteUrl, String? replyToId, String? replyToText, String? replyToSenderRole}) {
    if (_channel == null || !isConnected.value) return;

    final data = {
      'type': 'message',
      'message': message,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (voiceNoteUrl != null) 'voiceNoteUrl': voiceNoteUrl,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSenderRole != null) 'replyToSenderRole': replyToSenderRole,
    };

    _channel?.sink.add(jsonEncode(data));
  }

  void sendTyping() {
    if (_channel != null && isConnected.value) {
      _channel?.sink.add(jsonEncode({'type': 'typing'}));
    }
  }

  void sendStopTyping() {
    if (_channel != null && isConnected.value) {
      _channel?.sink.add(jsonEncode({'type': 'stop_typing'}));
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_currentUserId != null && !isConnected.value) {
        _establishConnection();
      }
    });
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close(1001); // 1001 is goingAway
    isConnected.value = false;
    isTyping.value = false;
  }

  @override
  void onClose() {
    _disconnect();
    _messageController.close();
    super.onClose();
  }
}
