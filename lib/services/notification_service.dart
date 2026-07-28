import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart'; // Add this
import 'firebase.dart';
import 'local_notification_db.dart';
import '../controller/home_controller.dart'; // Add this

final FirebaseMessaging _messaging = FirebaseMessaging.instance;

class NotificationService {
  final dataBase db;
  final LocalNotificationDb _localDb = LocalNotificationDb();

  NotificationService(this.db);

  Future<void> init() async {
    await _messaging.requestPermission();

    final token = await _messaging.getToken();

    if (token != null) {
      await db.updateFCMToken(token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      db.updateFCMToken(newToken);
    });

    // Listen for foreground messages and save them locally
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await saveNotificationLocally(message);
      
      // Update unread count in HomeController if it's registered
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().updateUnreadCount();
      }
    });
  }

  Future<void> saveNotificationLocally(RemoteMessage message) async {
    final notification = message.notification;
    
    // Extract title, body and link from either notification object OR data payload
    String? title = notification?.title ?? message.data['title'] ?? message.data['header'];
    String? body = notification?.body ?? message.data['body'] ?? message.data['message'] ?? message.data['content'];
    String? link = (message.data['link'] ?? message.data['deepLink'] ?? '').toString();

    if (title != null || body != null) {
      String type = message.data['type'] ?? 'general';
      
      final lowerTitle = title?.toLowerCase() ?? '';
      final lowerBody = body?.toLowerCase() ?? '';
      final lowerLink = link.toLowerCase();

      // Broad heuristic to catch "New Message from Admin" and similar patterns
      if (type == 'general') {
        if (lowerTitle.contains('message') || 
            lowerTitle.contains('chat') || 
            lowerTitle.contains('admin') ||
            lowerBody.contains('message') ||
            lowerBody.contains('chat') ||
            lowerLink.contains('/message') ||
            message.data['chatId'] != null || 
            message.data['senderId'] != null) {
          type = 'chat';
        }
      }

      await _localDb.insertNotification({
        'title': title,
        'body': body,
        'image': notification?.android?.imageUrl ?? notification?.apple?.imageUrl ?? message.data['image'],
        'link': link,
        'createdAt': DateTime.now().toIso8601String(),
        'type': type,
      });
    }
  }

  Future<String?> createFCMToken() async {
    await _messaging.requestPermission();

    String? token = await _messaging.getToken();

    return token;
  }
}
