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
import 'package:sizer/sizer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseAuth.instance.setLanguageCode('ar');

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

    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(context),
        darkTheme: AppTheme.darkTheme(context),
        themeMode: themeController.themeMode,
        locale: const Locale('ar'),
        textDirection: TextDirection.rtl,
        initialRoute: isLoggedIn ? AppPages.home : AppPages.root,
        getPages: AppRoutes.routes,
      ),
    );
  }
}
