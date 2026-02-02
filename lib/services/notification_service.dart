import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase.dart';

final FirebaseMessaging _messaging = FirebaseMessaging.instance;

class NotificationService {
  final dataBase db;

  NotificationService(this.db);

  Future<void> init() async {
    final token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
      await db.updateFCMToken(token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      db.updateFCMToken(newToken);
    });
  }

  Future<String?> createFCMToken() async {
    await _messaging.requestPermission();

    String? token = await _messaging.getToken();

    print("FCM TOKEN: $token");

    return token;
  }
}
