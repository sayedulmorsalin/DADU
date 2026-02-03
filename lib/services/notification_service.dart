import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase.dart';

final FirebaseMessaging _messaging = FirebaseMessaging.instance;

class NotificationService {
  final dataBase db;

  NotificationService(this.db);

  Future<void> init() async {
    await _messaging.requestPermission();

    final token = await _messaging.getToken();

    if (token != null) {
      print("🔥 FCM TOKEN: $token");
      await db.updateFCMToken(token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      print("🔄 NEW FCM TOKEN: $newToken");
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
