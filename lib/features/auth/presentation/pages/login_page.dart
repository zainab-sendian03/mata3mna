import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/themes/app_colors.dart';
import 'package:mata3mna/config/themes/assets.dart';
import 'package:mata3mna/core/constants/customAppBar.dart';
import 'package:mata3mna/core/constants/customButton.dart';
import 'package:mata3mna/core/constants/customTextForm.dart';
import 'package:mata3mna/features/auth/presentation/controllers/auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  AuthController authController = Get.find<AuthController>();
  final formKey_login = GlobalKey<FormState>();
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive breakpoints
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    
    // Responsive sizing - cap at reasonable maximums for desktop
    final horizontalPadding = isDesktop ? 40.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isDesktop ? 40.0 : (isTablet ? 32.0 : 24.0);
    final titleSize = isDesktop ? 28.0 : (isTablet ? 26.0 : 24.0);
    final spacing = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);
    final titleSpacing = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);
    final forgotPasswordSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);

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
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Form(
          key: formKey_login,
          child: Column(
            children: [
              /// --- Logo or title ---
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    "أهلاً بك، سجل دخول مطعمك !",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: titleSize,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              SizedBox(height: titleSpacing),

              /// --- Email ---
              CustomTextFormField(
                hintText: "البريد الإلكتروني",
                controller: authController.loginEmailController,
                min: 10,
                max: 100,
              ),
              SizedBox(height: spacing),

              /// --- Password ---
              CustomTextFormField(
                hintText: "كلمة المرور",
                controller: authController.loginPasswordController,
                min: 8,
                max: 20,
                visPassword: true,
                showVisPasswordToggle: true,
              ),

              SizedBox(height: spacing * 0.75),

              /// --- Forgot Password ---
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _showForgotPasswordDialog(context),
                  child: Text(
                    "نسيت كلمة المرور؟",
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: forgotPasswordSize,
                    ),
                  ),
                ),
              ),

              SizedBox(height: spacing * 0.75),

              /// --- Login button ---
              Obx(
                () => CustomButton(
                  onPressed: () async {
                    await authController.signInWithEmail(
                      authController.loginEmailController.text,
                      authController.loginPasswordController.text,
                      formKey_login,
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
              SizedBox(height: spacing * 1.5),
              Padding(
                padding: EdgeInsets.symmetric(vertical: spacing),
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

              SizedBox(height: spacing),

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final dialogWidth = isDesktop ? 500.0 : (isTablet ? 450.0 : screenWidth * 0.9);
    final padding = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);
    final spacing = isDesktop ? 20.0 : (isTablet ? 18.0 : 16.0);

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(padding),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "إعادة تعيين كلمة المرور",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: spacing * 0.5),
                Text(
                  "أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                ),
                SizedBox(height: spacing),
                CustomTextFormField(
                  hintText: "البريد الإلكتروني",
                  controller: emailController,
                  min: 10,
                  max: 100,
                ),
                SizedBox(height: spacing * 0.75),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        "إلغاء",
                        style: TextStyle(fontSize: isDesktop ? 16 : 14),
                      ),
                    ),
                    SizedBox(width: 12),
                    Obx(
                      () => ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 24 : 20,
                            vertical: isDesktop ? 16 : 12,
                          ),
                        ),
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
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "إرسال",
                                style: TextStyle(fontSize: isDesktop ? 16 : 14),
                              ),
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
