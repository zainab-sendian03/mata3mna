import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/themes/app_colors.dart';
import 'package:mata3mna/config/themes/assets.dart';
import 'package:mata3mna/core/constants/customAppBar.dart';
import 'package:mata3mna/core/constants/customButton.dart';
import 'package:mata3mna/core/constants/customTextForm.dart';
import 'package:mata3mna/core/constants/screen_extension.dart';
import 'package:mata3mna/features/auth/presentation/controllers/auth_controller.dart';
import 'package:sizer/sizer.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  AuthController authController = Get.find<AuthController>();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = context.screenHeight;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 249, 245, 237),
      appBar: CurvyImageAppBar(
        imageUrl: Assets.assetsImagesFood,
        icon: IconButton(
          icon: Icon(Icons.arrow_forward_sharp, color: Colors.white, size: 28),
          onPressed: () {
            Get.offAllNamed(AppPages.root);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
        child: Form(
          key: authController.formKey_login,
          child: Column(
            children: [
              /// --- Logo or title ---
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    "أهلاً بك، سجل دخول مطعمك !",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              SizedBox(height: height * 0.06),

              /// --- Email ---
              CustomTextFormField(
                hintText: "البريد الإلكتروني",
                controller: authController.loginEmailController,
                min: 10,
                max: 100,
              ),
              SizedBox(height: height * 0.03),

              /// --- Password ---
              CustomTextFormField(
                hintText: "كلمة المرور",
                controller: authController.loginPasswordController,
                min: 8,
                max: 20,
                visPassword: true,
                showVisPasswordToggle: true,
              ),

              SizedBox(height: height * 0.02),

              /// --- Forgot Password ---
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _showForgotPasswordDialog(context),
                  child: Text(
                    "نسيت كلمة المرور؟",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),

              SizedBox(height: height * 0.02),

              /// --- Login button ---
              Obx(
                () => CustomButton(
                  onPressed: () async {
                    await authController.signInWithEmail(
                      authController.loginEmailController.text,
                      authController.loginPasswordController.text,
                    );
                  },
                  theme: theme,
                  label: authController.isLoading.value
                      ? "الارجاء الانتظار...."
                      : "تسجيل الدخول",
                  color: authController.isLoading.value
                      ? AppColors.primaryLight.withOpacity(0.6)
                      : AppColors.primaryLight,
                  icon: null,
                ),
              ),
              SizedBox(height: 4.h),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 3.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Theme.of(context).shadowColor,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        "أو",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).shadowColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Theme.of(context).shadowColor,
                      ),
                    ),
                  ],
                ),
              ),

              /// --- Google button ---
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      txtColor: theme.shadowColor,
                      onPressed: () {
                        authController.signInWithGoogle();
                      },
                      theme: theme,
                      label: authController.isGoogleLoading.value
                          ? "الارجاء الانتظار...."
                          : " سجل الدخول باستخدام Google",
                      color: Color.fromARGB(255, 214, 214, 215),
                      icon: Image.asset(
                        Assets.assetsImagesGoogle,
                        height: 20,
                        width: 20,
                      ),
                    ),
                  ),
                  // SizedBox(width: 10),
                  // Expanded(
                  //   child: CustomButton(
                  //     onPressed: () {},
                  //     theme: theme,
                  //     label: "فيسبوك",
                  //     color: AppColors.facebookColor,
                  //     icon: MdiIcons.facebook,
                  //     isIcon: false,
                  //   ),
                  // ),
                ],
              ),

              SizedBox(height: 3.h),

              /// --- Sign up text ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "ليس لديك حساب؟ ",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Get.toNamed(AppPages.signUp),
                    child: Text(
                      "إنشاء حساب جديد",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "إعادة تعيين كلمة المرور",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 2.h),
                Text(
                  "أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 2.h),
                CustomTextFormField(
                  hintText: "البريد الإلكتروني",
                  controller: emailController,
                  min: 10,
                  max: 100,
                ),
                SizedBox(height: 3.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text("إلغاء"),
                    ),
                    SizedBox(width: 2.w),
                    Obx(
                      () => ElevatedButton(
                        onPressed: authController.isLoading.value
                            ? null
                            : () async {
                                if (formKey.currentState!.validate()) {
                                  await authController.sendPasswordResetEmail(
                                    emailController.text.trim(),
                                  );
                                  Navigator.pop(context);

                                  Get.back();
                                }
                              },
                        child: authController.isLoading.value
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text("إرسال"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
