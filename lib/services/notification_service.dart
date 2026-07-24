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
    if (notification != null) {
      await _localDb.insertNotification({
        'title': notification.title,
        'body': notification.body,
        'image': notification.android?.imageUrl ?? notification.apple?.imageUrl,
        'link': message.data['link'] ?? message.data['deepLink'],
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<String?> createFCMToken() async {
    await _messaging.requestPermission();

    String? token = await _messaging.getToken();

    return token;
  }
}
