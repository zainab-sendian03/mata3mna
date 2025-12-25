import 'dart:math';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/themes/app_colors.dart';
import 'package:mata3mna/config/themes/assets.dart';
import 'package:mata3mna/core/constants/customAppBar.dart';
import 'package:mata3mna/core/constants/customButton.dart';
import 'package:mata3mna/core/constants/customTextForm.dart';
import 'package:mata3mna/core/constants/screen_extension.dart';
import 'package:mata3mna/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final authController = Get.find<AuthController>();
  final formKey_signUp = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = context.screenHeight;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 249, 245, 237),
      appBar: CurvyImageAppBar(
        imageUrl: Assets.assetsImagesFood,
        icon: Icon(Icons.arrow_forward_sharp, color: Colors.white, size: 28),
      ),
      body: Obx(() {
        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),

              child: Form(
                key: formKey_signUp,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          "أنشئ حساب جديد لـ مطعمك !",
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: height * 0.06),
                    const SizedBox(height: 20),
                    CustomTextFormField(
                      validationType: "email",
                      hintText: "الإيميل",
                      controller: authController.signupEmailController,
                      min: 8,
                      max: 100,
                    ),
                    const SizedBox(height: 20),
                    CustomTextFormField(
                      validationType: "password",
                      hintText: "كلمة السر",
                      controller: authController.signupPasswordController,
                      visPassword: true,
                      showVisPasswordToggle: true,
                      min: 8,
                      max: 50,
                    ),
                    const SizedBox(height: 20),
                    CustomTextFormField(
                      validationType: "password",
                      hintText: "تأكيد كلمة السر",
                      controller: authController.confirmPasswordController,
                      visPassword: true,
                      showVisPasswordToggle: true,
                      min: 8,
                      max: 50,
                    ),
                    const SizedBox(height: 23),
                    SizedBox(
                      width: double.infinity,
                      height: max(context.screenHeight * 0.06, 50),
                      child: CustomButton(
                        onPressed: () async {
                          await authController.signUpWithEmailAndPassword(
                            authController.signupEmailController.text,
                            authController.signupPasswordController.text,
                            authController.confirmPasswordController.text,
                            formKey_signUp,
                          );
                        },
                        label: authController.isLoading.value
                            ? "الارجاء الانتظار...."
                            : "إنشاء الحساب",
                        color: authController.isLoading.value
                            ? AppColors.primaryLight.withOpacity(0.6)
                            : AppColors.primaryLight,
                        theme: theme,
                        icon: null,
                      ),
                    ),
                    SizedBox(height: 3.h),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "لديك حساب مسبقاً؟",
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(-10, 0),
                          child: TextButton(
                            onPressed: () {
                              Get.toNamed(AppPages.login);
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),

                            child: Text(
                              "تسجيل دخول",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
