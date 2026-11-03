import 'dart:async';
import 'dart:math' as math;
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

class _SplashParticle {
  final double xRatio;
  final double yRatio;
  final double size;
  final double speed;
  final double baseOpacity;

  const _SplashParticle({
    required this.xRatio,
    required this.yRatio,
    required this.size,
    required this.speed,
    required this.baseOpacity,
  });
}

class _FloatingParticlesPainter extends CustomPainter {
  final double progress;
  final List<_SplashParticle> particles;

  _FloatingParticlesPainter({
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final currentY = (p.yRatio * size.height - (progress * p.speed * size.height * 0.45)) % size.height;
      final currentX = p.xRatio * size.width + math.sin((progress * 2 * math.pi) + (p.xRatio * 8)) * 8.0;

      final shimmer = 0.70 + 0.30 * math.sin((progress * 4 * math.pi) + (p.yRatio * 10));
      final alpha = (p.baseOpacity * shimmer).clamp(0.0, 1.0);

      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(currentX, currentY), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  String _loadingStatusText = "Loading DADU...";

  late final AnimationController _entranceController;
  late final AnimationController _loopController;
  late final AnimationController _sheenController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoRotate;
  late final Animation<double> _shockwaveRadius;
  late final Animation<double> _shockwaveOpacity;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleLetterSpacing;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _bottomFade;

  static const List<_SplashParticle> _particles = [
    _SplashParticle(xRatio: 0.15, yRatio: 0.20, size: 3.0, speed: 0.8, baseOpacity: 0.32),
    _SplashParticle(xRatio: 0.82, yRatio: 0.15, size: 2.2, speed: 1.1, baseOpacity: 0.26),
    _SplashParticle(xRatio: 0.28, yRatio: 0.45, size: 4.2, speed: 0.6, baseOpacity: 0.22),
    _SplashParticle(xRatio: 0.75, yRatio: 0.60, size: 2.8, speed: 1.0, baseOpacity: 0.30),
    _SplashParticle(xRatio: 0.40, yRatio: 0.80, size: 3.5, speed: 0.7, baseOpacity: 0.25),
    _SplashParticle(xRatio: 0.10, yRatio: 0.70, size: 2.0, speed: 1.2, baseOpacity: 0.35),
    _SplashParticle(xRatio: 0.90, yRatio: 0.40, size: 3.2, speed: 0.9, baseOpacity: 0.28),
    _SplashParticle(xRatio: 0.50, yRatio: 0.25, size: 2.5, speed: 1.0, baseOpacity: 0.30),
    _SplashParticle(xRatio: 0.65, yRatio: 0.85, size: 3.8, speed: 0.65, baseOpacity: 0.24),
    _SplashParticle(xRatio: 0.33, yRatio: 0.12, size: 2.0, speed: 1.15, baseOpacity: 0.28),
    _SplashParticle(xRatio: 0.88, yRatio: 0.75, size: 4.0, speed: 0.75, baseOpacity: 0.20),
    _SplashParticle(xRatio: 0.05, yRatio: 0.35, size: 2.6, speed: 0.95, baseOpacity: 0.32),
    _SplashParticle(xRatio: 0.58, yRatio: 0.48, size: 3.0, speed: 0.85, baseOpacity: 0.25),
    _SplashParticle(xRatio: 0.22, yRatio: 0.90, size: 2.4, speed: 1.05, baseOpacity: 0.28),
    _SplashParticle(xRatio: 0.70, yRatio: 0.30, size: 3.6, speed: 0.7, baseOpacity: 0.26),
    _SplashParticle(xRatio: 0.45, yRatio: 0.65, size: 2.1, speed: 1.1, baseOpacity: 0.32),
    _SplashParticle(xRatio: 0.80, yRatio: 0.92, size: 3.4, speed: 0.8, baseOpacity: 0.22),
    _SplashParticle(xRatio: 0.12, yRatio: 0.52, size: 2.7, speed: 0.9, baseOpacity: 0.30),
    _SplashParticle(xRatio: 0.60, yRatio: 0.10, size: 4.1, speed: 0.6, baseOpacity: 0.18),
    _SplashParticle(xRatio: 0.95, yRatio: 0.22, size: 2.3, speed: 1.25, baseOpacity: 0.28),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initAppInBackground();
  }

  void _initAnimations() {
    // 1. Entrance animation sequence
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.52, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    _logoRotate = Tween<double>(begin: -0.07, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.52, curve: Curves.easeOutCubic),
      ),
    );

    // Shockwave pulse upon logo landing
    _shockwaveRadius = Tween<double>(begin: 40.0, end: 180.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.28, 0.70, curve: Curves.easeOutQuad),
      ),
    );

    _shockwaveOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.28, 0.70, curve: Curves.easeOut),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.38, 0.72, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.45),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.38, 0.72, curve: Curves.easeOutCubic),
      ),
    );

    // Cinematic letter spacing: expands inward from 15.0 to 7.0
    _titleLetterSpacing = Tween<double>(begin: 15.0, end: 7.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.38, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 0.88, curve: Curves.easeOut),
      ),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.45),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 0.88, curve: Curves.easeOutCubic),
      ),
    );

    _bottomFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
      ),
    );

    // 2. Loop controller for particles, levitation, rotating halo, and comet progress
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    // 3. Diagonal light sheen sweep across logo
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _loopController.dispose();
    _sheenController.dispose();
    super.dispose();
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

    final elapsedMs = stopwatch.elapsedMilliseconds;
    const minSplashMs = 2800;
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

  Widget _buildAmbientCornerIcon({
    required IconData icon,
    required double top,
    required double bottom,
    required double left,
    required double right,
    required double phase,
  }) {
    return Positioned(
      top: top > 0 ? top : null,
      bottom: bottom > 0 ? bottom : null,
      left: left > 0 ? left : null,
      right: right > 0 ? right : null,
      child: AnimatedBuilder(
        animation: _loopController,
        builder: (context, child) {
          final dy = math.sin((_loopController.value * 2 * math.pi) + phase) * 6.0;
          return Transform.translate(
            offset: Offset(0, dy),
            child: child,
          );
        },
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.2,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.black.withValues(alpha: 0.18),
            size: 26,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCB400),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFC526),
              Color(0xFFFCB400),
              Color(0xFFF59E0B),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Floating ambient sparks/particles
            AnimatedBuilder(
              animation: _loopController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FloatingParticlesPainter(
                    progress: _loopController.value,
                    particles: _particles,
                  ),
                  size: Size.infinite,
                );
              },
            ),

            // 2. Subtle ambient floating corner watermark icons
            _buildAmbientCornerIcon(
              icon: Icons.sports_soccer_rounded,
              top: 70,
              bottom: 0,
              left: 28,
              right: 0,
              phase: 0.0,
            ),
            _buildAmbientCornerIcon(
              icon: Icons.shopping_bag_outlined,
              top: 70,
              bottom: 0,
              left: 0,
              right: 28,
              phase: 1.5,
            ),
            _buildAmbientCornerIcon(
              icon: Icons.verified_outlined,
              top: 0,
              bottom: 140,
              left: 32,
              right: 0,
              phase: 3.0,
            ),
            _buildAmbientCornerIcon(
              icon: Icons.local_fire_department_outlined,
              top: 0,
              bottom: 140,
              left: 0,
              right: 32,
              phase: 4.5,
            ),

            // 3. Ambient pulsing background rings + rotating aura
            Center(
              child: AnimatedBuilder(
                animation: _loopController,
                builder: (context, child) {
                  final pulse = 1.0 + 0.07 * math.sin(_loopController.value * 2 * math.pi);
                  return Transform.scale(
                    scale: pulse,
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ripple
                    Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.035),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Rotating soft aura
                    AnimatedBuilder(
                      animation: _loopController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _loopController.value * 2 * math.pi,
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.20),
                                  const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Middle ring
                    Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.05),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Inner translucent circle
                    Container(
                      width: 165,
                      height: 165,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Logo impact shockwave burst
            Center(
              child: AnimatedBuilder(
                animation: _entranceController,
                builder: (context, _) {
                  if (_shockwaveOpacity.value <= 0.01) return const SizedBox.shrink();
                  return Container(
                    width: _shockwaveRadius.value * 2,
                    height: _shockwaveRadius.value * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: _shockwaveOpacity.value),
                        width: 3.5,
                      ),
                    ),
                  );
                },
              ),
            ),

            // 5. Centerpiece: Levitating Logo + Cinematic DADU + Tagline
            Center(
              child: AnimatedBuilder(
                animation: _loopController,
                builder: (context, child) {
                  // Levitating float bob
                  final levitateY = math.sin(_loopController.value * 2 * math.pi) * 5.0;
                  return Transform.translate(
                    offset: Offset(0, levitateY),
                    child: child,
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Logo Squircle with entrance bounce & continuous sheen
                    AnimatedBuilder(
                      animation: _entranceController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScale.value,
                          child: Transform.rotate(
                            angle: _logoRotate.value,
                            child: Opacity(
                              opacity: _logoFade.value,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 126,
                        height: 126,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.40),
                              blurRadius: 22,
                              spreadRadius: 3,
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.90),
                            width: 2.2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Image.asset(
                                'assets/logo/black_logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/icon/Logo.jpg',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            // Animated diagonal light sheen sweep over the logo
                            AnimatedBuilder(
                              animation: _sheenController,
                              builder: (context, child) {
                                return FractionalTranslation(
                                  translation: Offset(
                                    (_sheenController.value * 3.5) - 1.2,
                                    0,
                                  ),
                                  child: Transform.rotate(
                                    angle: 0.5,
                                    child: Container(
                                      width: 38,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0.0),
                                            Colors.white.withValues(alpha: 0.38),
                                            Colors.white.withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Animated DADU Title with Cinematic Letter Spacing
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: AnimatedBuilder(
                          animation: _titleLetterSpacing,
                          builder: (context, _) {
                            return Text(
                              'DADU',
                              style: GoogleFonts.montserrat(
                                fontSize: 37,
                                fontWeight: FontWeight.w900,
                                letterSpacing: _titleLetterSpacing.value,
                                color: const Color(0xFF1E1E1E),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Animated decorative divider
                    FadeTransition(
                      opacity: _titleFade,
                      child: Container(
                        width: 42,
                        height: 3.2,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Animated Tagline
                    SlideTransition(
                      position: _taglineSlide,
                      child: FadeTransition(
                        opacity: _taglineFade,
                        child: Text(
                          'PREMIUM FOOTWEAR & SPORTS GEAR',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                            color: Colors.black.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 6. Bottom Loading indicator & status
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: FadeTransition(
                opacity: _bottomFade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Modern animated comet progress bar
                    Container(
                      width: 150,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedBuilder(
                        animation: _loopController,
                        builder: (context, _) {
                          return FractionalTranslation(
                            translation: Offset((_loopController.value * 2.4) - 0.7, 0),
                            child: Container(
                              width: 55,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF1E1E1E).withValues(alpha: 0.1),
                                    const Color(0xFF1E1E1E),
                                    const Color(0xFF1E1E1E).withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _loadingStatusText,
                        key: ValueKey<String>(_loadingStatusText),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.65),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
