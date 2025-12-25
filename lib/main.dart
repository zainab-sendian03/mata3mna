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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseAuth.instance.setLanguageCode('ar');

  await Supabase.initialize(
    url: 'https://vuzfcwqmkulqttmgpwqn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ1emZjd3Fta3VscXR0bWdwd3FuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMjAyOTcsImV4cCI6MjA3OTc5NjI5N30.ZK3gt-h7vbvyixnmsm2LS-hG3kUOErlNMd_m5orFxXs',
  );

  // try {
  //   await FirebaseAppCheck.instance.activate(
  //     androidProvider: AndroidProvider.debug,
  //   );
  // } catch (_) {
  //   // optional
  // }

  final cacheHelper = Get.put(CacheHelper());
  await cacheHelper.init();

  ServiceLocator.init();
  Get.put(ThemeController());

  runApp(Sizer(builder: (context, orientation, deviceType) => MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final cacheHelper = Get.find<CacheHelper>();

    final bool isLoggedIn =
        cacheHelper.getData(key: 'isLoggedIn') as bool? ?? false;
    final String? userRole = cacheHelper.getData(key: 'userRole') as String?;
    print('User role: $userRole, isLoggedIn: $isLoggedIn');

    // Determine initial route based on login status and role
    // For owners, don't navigate to restaurant info here - let AuthController
    // check email verification first and navigate appropriately
    String initialRoute;
    // Customers don't need to be logged in - they just need a role
    if (userRole == 'customer') {
      initialRoute = AppPages.customerView;
    } else if (userRole == 'admin') {
      // Admins always start at admin login page, regardless of login status
      initialRoute = AppPages.adminLogin;
    } else if (isLoggedIn && userRole == 'owner') {
      // Start at root for owners - AuthController will check email verification
      // and navigate to verify email screen if not verified, or to appropriate
      // screen (home/restaurant info) if verified
      initialRoute = AppPages.root;
    } else {
      initialRoute = AppPages.root;
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
