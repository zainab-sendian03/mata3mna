import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/themes/app_colors.dart';
import 'package:mata3mna/config/themes/assets.dart';
import 'package:mata3mna/core/constants/customAppBar.dart';
import 'package:mata3mna/core/constants/customButton.dart';
import 'package:mata3mna/core/constants/customTextForm.dart';
import 'package:mata3mna/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  AuthController authController = Get.find<AuthController>();
  final formKey_login = GlobalKey<FormState>();
  bool _rememberMe = false;
  final CacheHelper _cacheHelper = Get.find<CacheHelper>();

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  void _loadRememberedEmail() {
    // Check if remember me was enabled
    final rememberMeEnabled =
        _cacheHelper.getData(key: 'admin_remember_me') as bool? ?? false;
    if (rememberMeEnabled) {
      final rememberedEmail =
          _cacheHelper.getData(key: 'admin_remembered_email') as String?;
      if (rememberedEmail != null && rememberedEmail.isNotEmpty) {
        setState(() {
          _rememberMe = true;
          authController.loginEmailController.text = rememberedEmail;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive breakpoints
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final isMobile = screenWidth <= 768;

    // Responsive sizing
    final maxWidth = isDesktop ? 500.0 : (isTablet ? 450.0 : double.infinity);
    final titleSize = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);
    final spacing = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 249, 245, 237),
      appBar: isMobile
          ? CurvyImageAppBar(
              imageUrl: Assets.assetsImagesFood,
              icon: IconButton(
                icon: Icon(
                  Icons.arrow_forward_sharp,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  Get.offAllNamed(AppPages.root);
                },
              ),
            )
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_forward_sharp,
                  color: colorScheme.onSurface,
                ),
                onPressed: () {
                  Get.offAllNamed(AppPages.root);
                },
              ),
            ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              minHeight: isDesktop
                  ? screenHeight - 200
                  : (isTablet ? screenHeight - 100 : 0),
            ),
            child: Container(
              padding: isDesktop
                  ? EdgeInsets.symmetric(vertical: 30, horizontal: 20)
                  : (isTablet
                        ? EdgeInsets.all(20)
                        : EdgeInsets.fromLTRB(16, 24, 16, 16)),

              decoration: isDesktop || isTablet
                  ? BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    )
                  : null,
              child: Form(
                key: formKey_login,
                child: Column(
                  mainAxisAlignment: isMobile
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    /// --- Logo or title ---
                    Text(
                      "تسجيل دخول المسؤول",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: spacing),

                    /// --- Email ---
                    CustomTextFormField(
                      hintText: "البريد الإلكتروني",
                      controller: authController.loginEmailController,
                      min: 10,
                      max: 100,
                    ),
                    SizedBox(height: spacing * 1),

                    /// --- Password ---
                    CustomTextFormField(
                      hintText: "كلمة المرور",
                      controller: authController.loginPasswordController,
                      min: 8,
                      max: 20,
                      visPassword: true,
                      showVisPasswordToggle: true,
                    ),

                    SizedBox(height: spacing * 0.5),

                    /// --- Remember Me Checkbox ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "تذكرني",
                          style: isDesktop
                              ? theme.textTheme.displaySmall?.copyWith(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                )
                              : theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                        ),
                        SizedBox(width: 8),
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: spacing * 0.5),

                    /// --- Login button ---
                    Obx(
                      () => CustomButton(
                        onPressed: () {
                          // Save remember me preference
                          if (_rememberMe) {
                            _cacheHelper.saveData(
                              key: 'admin_remember_me',
                              value: true,
                            );
                            _cacheHelper.saveData(
                              key: 'admin_remembered_email',
                              value: authController.loginEmailController.text
                                  .trim(),
                            );
                          } else {
                            _cacheHelper.removeData(key: 'admin_remember_me');
                            _cacheHelper.removeData(
                              key: 'admin_remembered_email',
                            );
                          }

                          authController.signInWithEmail(
                            authController.loginEmailController.text,
                            authController.loginPasswordController.text,
                            formKey_login,
                            rememberMe: _rememberMe,
                          );
                        },
                        theme: theme,
                        label: authController.isLoading.value
                            ? "الارجاء الانتظار...."
                            : "تسجيل الدخول",
                        color: AppColors.primaryLight,
                        icon: null,
                        isLoading: authController.isLoading.value,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // void _showForgotPasswordDialog(BuildContext context) {
  //   final emailController = TextEditingController();
  //   final formKey = GlobalKey<FormState>();
  //   final screenWidth = MediaQuery.of(context).size.width;
  //   final isDesktop = screenWidth > 1200;
  //   final isTablet = screenWidth > 768 && screenWidth <= 1200;
  //   final dialogWidth = isDesktop
  //       ? 500.0
  //       : (isTablet ? 450.0 : screenWidth * 0.9);
  //   final padding = isDesktop ? 40.0 : (isTablet ? 32.0 : 24.0);

  //   Get.dialog(
  //     Dialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  //       child: Container(
  //         width: dialogWidth,
  //         padding: EdgeInsets.all(padding),
  //         child: Form(
  //           key: formKey,
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 "إعادة تعيين كلمة المرور",
  //                 style: Theme.of(
  //                   context,
  //                 ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
  //               ),
  //               SizedBox(height: padding * 0.5),
  //               Text(
  //                 "أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين",
  //                 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
  //                   color: Theme.of(
  //                     context,
  //                   ).colorScheme.onSurface.withOpacity(0.7),
  //                 ),
  //               ),
  //               SizedBox(height: padding),
  //               CustomTextFormField(
  //                 hintText: "البريد الإلكتروني",
  //                 controller: emailController,
  //                 min: 10,
  //                 max: 100,
  //               ),
  //               SizedBox(height: padding * 0.75),
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.end,
  //                 children: [
  //                   TextButton(
  //                     onPressed: () => Get.back(),
  //                     child: Text(
  //                       "إلغاء",
  //                       style: TextStyle(fontSize: isDesktop ? 16 : 14),
  //                     ),
  //                   ),
  //                   SizedBox(width: 12),
  //                   Obx(
  //                     () => ElevatedButton(
  //                       style: ElevatedButton.styleFrom(
  //                         padding: EdgeInsets.symmetric(
  //                           horizontal: isDesktop ? 24 : 20,
  //                           vertical: isDesktop ? 16 : 12,
  //                         ),
  //                       ),
  //                       onPressed: authController.isLoading.value
  //                           ? null
  //                           : () async {
  //                               if (formKey.currentState!.validate()) {
  //                                 await authController.sendPasswordResetEmail(
  //                                   emailController.text.trim(),
  //                                 );
  //                                 Navigator.pop(context);
  //                                 Get.back();
  //                               }
  //                             },
  //                       child: authController.isLoading.value
  //                           ? SizedBox(
  //                               width: 20,
  //                               height: 20,
  //                               child: CircularProgressIndicator(
  //                                 strokeWidth: 2,
  //                               ),
  //                             )
  //                           : Text(
  //                               "إرسال",
  //                               style: TextStyle(fontSize: isDesktop ? 16 : 14),
  //                             ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }
}
