import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/features/auth/presentation/controllers/auth_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AuthController authController = Get.find<AuthController>();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        title: Text(
          'مطاعمنا',
          style: TextStyle(color: theme.scaffoldBackgroundColor),
        ),
        actions: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.14159),
            child: IconButton(
              onPressed: () async {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    title: const Text(
                      "تسجيل الدخول",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: const Text("هل أنت متأكد أنك تريد تسجيل الخروج؟"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("إلغاء"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await authController.signOut();
                          authController.confirmPasswordController.clear();
                          authController.usernameController.clear();
                          authController.signupEmailController.clear();
                          authController.signupPasswordController.clear();
                          authController.loginEmailController.clear();
                          authController.loginPasswordController.clear();
                        },
                        child: Text(
                          "تسجيل خروج",
                          style: TextStyle(
                            color: Theme.of(context).scaffoldBackgroundColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: Icon(
                Icons.logout_rounded,
                color: theme.scaffoldBackgroundColor,
              ),
            ),
          ),
        ],
      ),
      body: Center(child: Text("......coming soon")),
    );
  }
}
