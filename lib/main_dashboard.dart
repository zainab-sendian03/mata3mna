import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/routes/app_routes.dart';
import 'package:mata3mna/config/themes/app_theme.dart';
import 'package:mata3mna/config/themes/theme_controller.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/core/di/service_locator.dart';
import 'package:mata3mna/features/auth/presentation/pages/admin_login_page.dart';
import 'package:mata3mna/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase for authentication
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
    final supabase = Supabase.instance.client;
    // Give Supabase time to restore session from storage
    await Future.delayed(const Duration(milliseconds: 300));

    final currentUser = supabase.auth.currentUser;

    if (currentUser != null) {
      try {
        // جلب دور المستخدم من جدول users في Supabase
        final response = await supabase
            .from('users')
            .select('role')
            .eq('id', currentUser.id)
            .maybeSingle();

        final role = response?['role'] as String?;

        if (role == 'admin') {
          // Small delay to ensure GetMaterialApp is ready
          await Future.delayed(const Duration(milliseconds: 100));
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

    // إذا ما في session أو مش admin
    setState(() {
      initialRoute = AppPages.adminLogin;
      _isCheckingAuth = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    if (_isCheckingAuth || initialRoute == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Use home instead of initialRoute to avoid "Could not navigate to initial route" error
    final isAdmin = initialRoute == AppPages.dashboard;

    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(context),
        darkTheme: AppTheme.darkTheme(context),
        themeMode: themeController.themeMode,
        locale: const Locale('ar'),
        textDirection: TextDirection.rtl,
        home: isAdmin ? const DashboardScreen() : const AdminLoginPage(),
        getPages: AppRoutes.routes,
        unknownRoute: GetPage(
          name: '/not-found',
          page: () => Scaffold(body: Center(child: Text('الصفحة غير موجودة'))),
        ),
      ),
    );
  }
}
