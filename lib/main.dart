import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/routes/app_routes.dart';
import 'package:mata3mna/config/themes/app_theme.dart';
import 'package:mata3mna/config/themes/theme_controller.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/core/di/service_locator.dart';
import 'package:mata3mna/features/restaurant_info/data/services/restaurant_firestore_service.dart';
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

  // Initialize Supabase for authentication
  await Supabase.initialize(
    url: 'https://vuzfcwqmkulqttmgpwqn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ1emZjd3Fta3VscXR0bWdwd3FuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMjAyOTcsImV4cCI6MjA3OTc5NjI5N30.ZK3gt-h7vbvyixnmsm2LS-hG3kUOErlNMd_m5orFxXs',
  );

  // Process auth callback from email verification link before app starts.
  // If user opened the app via the verification link, recover session now
  // so _checkAuthAndSetRoute can route to /complete-restaurant-info.
  if (!kIsWeb) {
    try {
      final uri = await AppLinks().getInitialLink();
      if (uri != null &&
          (uri.host == 'auth-callback' ||
              uri.host == 'login-callback' ||
              uri.path.contains('auth-callback')) &&
          (uri.fragment.contains('access_token') ||
              uri.queryParameters.containsKey('code'))) {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      }
    } catch (_) {}
  }

  final cacheHelper = Get.put(CacheHelper());
  await cacheHelper.init();

  ServiceLocator.init();
  Get.put(ThemeController());

  runApp(Sizer(builder: (context, orientation, deviceType) => MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? initialRoute;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuthAndSetRoute();
  }

  Future<void> _checkAuthAndSetRoute() async {
    final cacheHelper = Get.find<CacheHelper>();
    final supabase = Supabase.instance.client;

    // Wait for Supabase to fire initialSession (session restore from storage)
    // initialize() returns before recoverSession completes - we must wait for the auth event
    Session? restoredSession;
    late StreamSubscription<AuthState> sub;
    final completer = Completer<void>();
    sub = supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.initialSession && !completer.isCompleted) {
        restoredSession = data.session;
        sub.cancel();
        completer.complete();
      }
    });
    try {
      await completer.future.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      sub.cancel();
    }

    final currentUser = restoredSession?.user ?? supabase.auth.currentUser;
    bool isLoggedIn =
        cacheHelper.getData(key: 'isLoggedIn') as bool? ?? false;
    String? userRole = cacheHelper.getData(key: 'userRole') as String?;

    // Restore login from Supabase session so user stays logged in across app restarts
    if (currentUser != null) {
      await cacheHelper.saveData(key: 'isLoggedIn', value: true);
      await cacheHelper.saveData(key: 'userUid', value: currentUser.id);
      await cacheHelper.saveData(
          key: 'userEmail', value: currentUser.email ?? '');
      isLoggedIn = true;
      if (userRole == null) {
        try {
          final userDoc = await supabase
              .from('users')
              .select('role')
              .eq('id', currentUser.id)
              .maybeSingle();
          final role = userDoc?['role']?.toString();
          if (role != null && role.isNotEmpty) {
            userRole = role;
            await cacheHelper.saveData(key: 'userRole', value: role);
          }
        } catch (_) {}
        if (userRole == null) {
          userRole = 'owner';
          await cacheHelper.saveData(key: 'userRole', value: userRole);
        }
      }
    }

    print('User role: $userRole, isLoggedIn: $isLoggedIn');

    // If owner is logged in, verify restaurant and sync completion status
    if (isLoggedIn && userRole == 'owner') {
      try {
        final uid = cacheHelper.getData(key: 'userUid') as String?;
        final email = cacheHelper.getData(key: 'userEmail') as String?;

        if (uid != null || email != null) {
          final restaurantService = Get.find<RestaurantSupabaseService>();
          final restaurantInfo =
              await restaurantService.getRestaurantByOwnerId(uid ?? '');

          if (restaurantInfo == null) {
            await cacheHelper.saveData(
              key: 'restaurantInfoCompleted',
              value: false,
            );
          } else {
            final completed = await restaurantService.getRestaurantInfoCompleted(
              ownerId: uid!,
              ownerEmail: email,
            );
            await cacheHelper.saveData(
              key: 'restaurantInfoCompleted',
              value: completed,
            );
          }
        }
      } catch (e) {
        print('[MyApp] Error checking restaurant: $e');
        await cacheHelper.saveData(
          key: 'restaurantInfoCompleted',
          value: false,
        );
      }
    }

    // Determine initial route based on login status and role
    // For owners, don't navigate to restaurant info here - let AuthController
    // check email verification first and navigate appropriately
    String route;
    // Customers don't need to be logged in - they just need a role
    if (userRole == 'customer') {
      route = AppPages.customerView;
    } else if (userRole == 'admin') {
      // Admins always start at admin login page, regardless of login status
      route = AppPages.adminLogin;
    } else if (isLoggedIn && userRole == 'owner') {
      // Owner: check email verification first - never show complete-restaurant-info before verify-email
      final authUser = currentUser;
      final isEmailConfirmed = authUser?.emailConfirmedAt != null;

      if (!isEmailConfirmed) {
        route = AppPages.verifyEmail;
      } else {
        final completed =
            cacheHelper.getData(key: 'restaurantInfoCompleted') as bool? ?? false;
        route = completed ? AppPages.home : AppPages.completeRestaurantInfo;
      }
    } else {
      route = AppPages.root;
    }

    setState(() {
      initialRoute = route;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    if (_isChecking || initialRoute == null) {
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
