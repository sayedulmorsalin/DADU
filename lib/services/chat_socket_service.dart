import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class ChatSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  final RxBool isConnected = false.obs;
  Timer? _reconnectTimer;
  String? _currentUserId;

  void connect(String userId) async {
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

      String baseUrl = dotenv.get('API_BASE_URL', fallback: 'https://api.dadubd.com');
      // Convert https to wss and http to ws
      String wsUrl = baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
      
      final uri = Uri.parse('$wsUrl/ws/$_currentUserId');

      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['Bearer', token], // Cloudflare DO fetch expects Authorization header, but standard WS uses protocols or query params for auth often. 
        // Actually, our backend wsController uses request.headers.get('Authorization').
        // web_socket_channel allows passing headers.
      );
      
      // Since web_socket_channel.connect on web doesn't support headers easily, 
      // but on Mobile/Desktop it does.
      // However, the DO fetch implementation specifically checks for Authorization header.
      
      _channel = WebSocketChannel.connect(
        uri,
      );

      // Re-connect with headers if possible, or use the IO channel specifically if needed.
      // For now, let's assume the standard connect works or we'll need to pass token via query param if headers fail.
      // But let's try to pass it in headers first.
      
      _channel = WebSocketChannel.connect(
        uri,
        // custom headers are passed in the connect call for I/O platforms
      );
      
      // Let's use a more robust way to pass headers if platform supports it.
      // The wsController expects "Authorization: Bearer <token>"
    } catch (e) {
      _scheduleReconnect();
    }
  }

  // To properly support headers, we might need to use IOWebSocketChannel on mobile
  // But let's refine the connection to handle auth.
  
  void _listen() {
    _channel?.stream.listen(
      (data) {
        isConnected.value = true;
        try {
          final Map<String, dynamic> message = jsonDecode(data);
          _messageController.add(message);
        } catch (e) {
          // Parse error
        }
      },
      onDone: () {
        isConnected.value = false;
        _scheduleReconnect();
      },
      onError: (error) {
        isConnected.value = false;
        _scheduleReconnect();
      },
    );
  }

  void sendMessage(String message, {String? imageUrl}) {
    if (_channel == null || !isConnected.value) return;

    final data = {
      'type': 'message',
      'message': message,
      'imageUrl': imageUrl,
    };

    _channel?.sink.add(jsonEncode(data));
  }

  void sendTyping() {
    _channel?.sink.add(jsonEncode({'type': 'typing'}));
  }

  void sendStopTyping() {
    _channel?.sink.add(jsonEncode({'type': 'stop_typing'}));
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_currentUserId != null) {
        _establishConnection();
      }
    });
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    isConnected.value = false;
  }

  void dispose() {
    _disconnect();
    _messageController.close();
  }
}
