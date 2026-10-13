import 'dart:async';
import 'package:dadu/controller/home_controller.dart';
import 'package:dadu/screen/product/home.dart';
import 'package:dadu/services/local_notification_db.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final notification = message.notification;
  if (notification != null) {
    await LocalNotificationDb().insertNotification({
      'title': notification.title,
      'body': notification.body,
      'image': notification.android?.imageUrl ?? notification.apple?.imageUrl,
      'link': message.data['link'] ?? message.data['deepLink'],
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _loadingStatusText = "Loading DADU...";

  @override
  void initState() {
    super.initState();
    // Run Background Initialization
    _initAppInBackground();
  }

  Future<void> _initAppInBackground() async {
    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      if (mounted) setState(() => _loadingStatusText = "Connecting to services...");

      // 1. Safe dotenv load with timeout
      try {
        await dotenv.load(fileName: ".env").timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        );
      } catch (_) {}

      // 2. FCM Background Handler & Topic Subscription (non-blocking)
      try {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        unawaited(FirebaseMessaging.instance.subscribeToTopic("allUsers"));
      } catch (_) {}

      // 3. Initialize Mobile Ads (non-blocking)
      try {
        MobileAds.instance.initialize();
      } catch (_) {}

      if (mounted) setState(() => _loadingStatusText = "Preparing store...");

      // 4. Pre-warm HomeController safely
      try {
        if (!Get.isRegistered<HomeController>()) {
          Get.put(HomeController());
        }
      } catch (_) {}

    } catch (e) {
      debugPrint("Initialization error: $e");
    }

    // Ensure minimum display duration (3.0 seconds) for the full GIF animation cycle
    final elapsedMs = stopwatch.elapsedMilliseconds;
    const minSplashMs = 3000;
    if (elapsedMs < minSplashMs) {
      await Future.delayed(Duration(milliseconds: minSplashMs - elapsedMs));
    }

    if (mounted) {
      Get.offAll(
        () => Home(),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCB400),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated GIF from assets
          Center(
            child: Image.asset(
              'assets/gif/splash.gif',
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Image.asset(
                    'assets/icon/Logo.jpg',
                    width: 150,
                    height: 150,
                  ),
                );
              },
            ),
          ),

          // Loading indicator & status while app is loading in the background
          Positioned(
            bottom: 36,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _loadingStatusText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
