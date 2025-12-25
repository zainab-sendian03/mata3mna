import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/routes/app_routes.dart';
import 'package:mata3mna/config/themes/app_theme.dart';
import 'package:mata3mna/config/themes/theme_controller.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/core/di/service_locator.dart';
import 'package:mata3mna/firebase_options.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stub background message handler for Firebase Messaging
/// This prevents errors when Firebase plugins expect this handler to be defined
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(dynamic message) async {
  // Stub handler - does nothing
  // If you add firebase_messaging package later, implement proper handling here
}

/// Standalone dashboard entry point for web
/// This runs only the dashboard without the full app flow
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseAuth.instance.setLanguageCode('ar');

  // Initialize Supabase (if needed for dashboard)
  await Supabase.initialize(
    url: 'https://vuzfcwqmkulqttmgpwqn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ1emZjd3Fta3VscXR0bWdwd3FuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMjAyOTcsImV4cCI6MjA3OTc5NjI5N30.ZK3gt-h7vbvyixnmsm2LS-hG3kUOErlNMd_m5orFxXs',
  );

  // Initialize cache
  final cacheHelper = Get.put(CacheHelper());
  await cacheHelper.init();

  // Initialize services
  ServiceLocator.init();
  Get.put(ThemeController());

  runApp(Sizer(builder: (context, orientation, deviceType) => DashboardApp()));
}

class DashboardApp extends StatefulWidget {
  const DashboardApp({super.key});

  @override
  State<DashboardApp> createState() => _DashboardAppState();
}

class _DashboardAppState extends State<DashboardApp> {
  String? initialRoute;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthAndSetRoute();
  }

  Future<void> _checkAuthAndSetRoute() async {
    // Check if Firebase Auth has a valid session
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // User is already authenticated, check if they're admin
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        final role = userDoc.data()?['role'] as String?;

        if (role == 'admin') {
          // Admin is authenticated, go to dashboard
          setState(() {
            initialRoute = AppPages.dashboard;
            _isCheckingAuth = false;
          });
          return;
        }
      } catch (e) {
        print('Error checking admin role: $e');
      }
    }

    // No valid session or not admin, go to login
    setState(() {
      initialRoute = AppPages.adminLogin;
      _isCheckingAuth = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    // Show loading while checking auth
    if (_isCheckingAuth || initialRoute == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(context),
        darkTheme: AppTheme.darkTheme(context),
        themeMode: themeController.themeMode,
        locale: const Locale('ar'),
        textDirection: TextDirection.rtl,
        initialRoute: initialRoute,
        getPages: AppRoutes.routes,
      ),
    );
  }
}
