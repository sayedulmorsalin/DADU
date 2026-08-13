import 'package:dadu/screen/splash/splash_screen.dart';
import 'package:dadu/services/deep_link_service.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp().timeout(const Duration(seconds: 3));
    }
  } catch (e) {
    debugPrint("Firebase init error in main: $e");
  }

  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Initialize deep link handling
    DeepLinkService().initDeepLinks(navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.scaffoldBackground,
        primaryColor: AppColors.primary,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.scaffoldBackground,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

