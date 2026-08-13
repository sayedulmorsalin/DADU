import 'dart:async';
import 'package:dadu/controller/home_controller.dart';
import 'package:dadu/screen/product/home.dart';
import 'package:dadu/services/local_notification_db.dart';
import 'package:dadu/theme/app_colors.dart';
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

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _shimmerController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<double> _textScale;
  late Animation<double> _shimmerValue;

  String _loadingStatusText = "Loading DADU...";

  @override
  void initState() {
    super.initState();

    // 1. Logo Animation Setup (Pulse + Scale + Fade)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // 2. DADU Text Animation Setup (Scale + Fade reveal)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _textScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // 3. Shimmer Glow Animation Setup
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _shimmerValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Start Animations
    _logoController.forward().then((_) {
      _textController.forward();
    });

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

    // Ensure minimum display duration (2.0 seconds) for smooth animation UX
    final elapsedMs = stopwatch.elapsedMilliseconds;
    const minSplashMs = 2000;
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
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14), // Luxurious dark background
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient gradient glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 1.2 + (_shimmerValue.value * 0.1),
                      colors: [
                        AppColors.primary.withValues(alpha: 0.25),
                        const Color(0xFF161622),
                        const Color(0xFF09090D),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // Main Center Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated App Icon / Logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoFade.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Container(
                          width: 110,
                          height: 110,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFFD54F),
                                AppColors.primary,
                                const Color(0xFFFF6F00),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon/Logo.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppColors.primary,
                                  child: const Icon(
                                    Icons.sports_soccer,
                                    size: 55,
                                    color: Colors.black,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Animated DADU Text with Custom Font & Metallic Gold Gradient
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textFade.value,
                      child: Transform.scale(
                        scale: _textScale.value,
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, child) {
                            return ShaderMask(
                              shaderCallback: (bounds) {
                                final shimmer = _shimmerValue.value;
                                return LinearGradient(
                                  colors: [
                                    const Color(0xFFFFF8E1),
                                    AppColors.primary,
                                    const Color(0xFFFF8F00),
                                    const Color(0xFFFFF8E1),
                                  ],
                                  stops: [
                                    (shimmer - 0.3).clamp(0.0, 1.0),
                                    shimmer,
                                    (shimmer + 0.3).clamp(0.0, 1.0),
                                    1.0,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds);
                              },
                              child: Text(
                                'DADU',
                                style: GoogleFonts.outfit(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 14.0,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: AppColors.primary.withValues(alpha: 0.6),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Subtitle / Tagline
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textFade.value,
                      child: Text(
                        'SPORTS & FITNESS STORE',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4.5,
                          color: Colors.white54,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Bottom Loading Indicator & Status Text
          Positioned(
            bottom: 60,
            child: Column(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _loadingStatusText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white38,
                    letterSpacing: 1.0,
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
