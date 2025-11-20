import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/features/auth/presentation/pages/login_page.dart';
import 'package:mata3mna/features/auth/presentation/pages/sign_up_page.dart';
import 'package:mata3mna/features/auth/presentation/pages/start_page.dart';
import 'package:mata3mna/features/auth/presentation/pages/verify_email_page.dart';
import 'package:mata3mna/features/home/presentation/pages/home_page.dart';

class AppRoutes {
  static final List<GetPage> routes = [
    GetPage(
      name: AppPages.root,
      page: () => const ChooseRolePage(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppPages.signUp,
      page: () => const SignUpPage(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppPages.login,
      page: () => const LoginPage(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppPages.verifyEmail,
      page: () {
        final args = Get.arguments as Map<String, dynamic>;
        return VerifyEmailScreen(
          email: args['email'],
          onResendVerification: args['onResendVerification'],
          onCheckVerification: args['onCheckVerification'],
          onLogout: args['onLogout'],
        );
      },
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: AppPages.home,
      page: () => const HomePage(),
      transition: Transition.fadeIn,
    ),
  ];
}
