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
      await db.updateFCMToken(token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      db.updateFCMToken(newToken);
    });
  }


  Future<String?> createFCMToken() async {
    await _messaging.requestPermission();

    String? token = await _messaging.getToken();

    return token;
  }
}
