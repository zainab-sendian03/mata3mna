import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/features/auth/domain/entities/user_entity.dart';
import 'package:mata3mna/features/auth/domain/repositories/auth_repository.dart';
import 'package:mata3mna/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:mata3mna/features/auth/domain/usecases/sign_up_with_email_and_password.dart';
import 'package:mata3mna/features/auth/domain/usecases/sign_out.dart';
import 'package:mata3mna/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:mata3mna/features/auth/domain/usecases/send_password_reset_email.dart';
import 'package:mata3mna/features/auth/domain/usecases/send_email_verification.dart';
import 'package:mata3mna/features/auth/domain/usecases/check_email_verification.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/features/auth/presentation/pages/verify_email_page.dart';

class AuthController extends GetxController {
  final AuthRepository _authRepository;

  // Use cases
  late final SignInWithEmail _signInWithEmail;
  late final SignUpWithEmailAndPassword _signUpWithEmailAndPassword;
  late final SignOut _signOut;
  late final SignInWithGoogle _signInWithGoogle;
  late final SendPasswordResetEmail _sendPasswordResetEmail;
  late final SendEmailVerification _sendEmailVerification;
  late final CheckEmailVerification _checkEmailVerification;
  final RxString errorMessage = "".obs;

  RxBool isLoading = false.obs;
  RxBool isGoogleLoading = false.obs;
  final cacheHelper = Get.find<CacheHelper>();

  final TextEditingController loginEmailController = TextEditingController();
  final TextEditingController loginPasswordController = TextEditingController();
  final TextEditingController signupEmailController = TextEditingController();
  final TextEditingController signupPasswordController =
      TextEditingController();

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  Rx<UserEntity?> currentUser = Rx<UserEntity?>(null);
  final formKey_login = GlobalKey<FormState>();
  final formKey_signUp = GlobalKey<FormState>();

  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  @override
  void onInit() {
    super.onInit();
    _initializeUseCases();
    ever(currentUser, _handleAuthStateChange);
    _checkCurrentUser();
  }

  void _handleAuthStateChange(UserEntity? user) async {
    if (user != null && user.uid != null) {
      final isVerified = await checkEmailVerification();
      if (isVerified) {
        Get.offAllNamed(AppPages.home);
      } else {
        // روحي على شاشة VerifyEmailScreen
        Get.offAll(
          () => VerifyEmailScreen(
            email: user.email ?? '',
            onResendVerification: () async {
              await sendEmailVerification();
            },
            onCheckVerification: () async {
              final verified = await checkEmailVerification();
              if (verified) {
                Get.offAllNamed(AppPages.home);
              } else {
                Get.snackbar(
                  "تحقق من بريدك",
                  "الإيميل لم يتم التحقق منه بعد",
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );
              }
            },
            onLogout: () async {
              await signOut();
            },
          ),
        );
      }
    }
  }

  // التحقق من المستخدم الحالي عند بدء التطبيق
  Future<void> _checkCurrentUser() async {
    try {
      final result = await _authRepository.getCurrentUser();
      result.fold(
        (failure) {
          // لا يوجد مستخدم مسجل دخول
          currentUser.value = null;
        },
        (user) {
          if (user != null && user.uid != null) {
            currentUser.value = user;
            // تحديث البيانات المحلية
            cacheHelper.saveData(key: 'isLoggedIn', value: true);
            cacheHelper.saveData(key: 'userUid', value: user.uid ?? '');
            cacheHelper.saveData(key: 'userEmail', value: user.email ?? '');
          } else {
            currentUser.value = null;
            cacheHelper.removeData(key: 'isLoggedIn');
            cacheHelper.removeData(key: 'userUid');
            cacheHelper.removeData(key: 'userEmail');
          }
        },
      );
    } catch (e) {
      print('Error checking current user: $e');
      currentUser.value = null;
    }
  }

  void _initializeUseCases() {
    _signInWithEmail = SignInWithEmail(_authRepository);
    _signUpWithEmailAndPassword = SignUpWithEmailAndPassword(_authRepository);
    _signOut = SignOut(_authRepository);
    _signInWithGoogle = SignInWithGoogle(_authRepository);
    _sendPasswordResetEmail = SendPasswordResetEmail(_authRepository);
    _sendEmailVerification = SendEmailVerification(_authRepository);
    _checkEmailVerification = CheckEmailVerification(_authRepository);
  }

  // تسجيل الدخول بالبريد
  Future<void> signInWithEmail(String email, String password) async {
    if (!formKey_login.currentState!.validate()) {
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _signInWithEmail(email, password);
      result.fold(
        (failure) {
          print('🔍 Failure statusCode: ${failure.statusCode}');
          print('🔍 Failure message: ${failure.errMessage}');

          if (failure.statusCode == 401 || failure.statusCode == 400) {
            errorMessage.value = "الإيميل أو كلمة المرور غير صحيحة";
          } else if (failure.statusCode == 500) {
            errorMessage.value = "خطأ في الخادم، يرجى المحاولة لاحقًا";
          } else {
            errorMessage.value = failure.errMessage.isNotEmpty
                ? failure.errMessage
                : "حدث خطأ غير متوقع";
          }

          Get.snackbar(
            "خطأ",
            errorMessage.value,
            snackPosition: SnackPosition.BOTTOM,
          );
        },
        (user) async {
          currentUser.value = user;
          await cacheHelper.saveData(key: 'isLoggedIn', value: true);
          await cacheHelper.saveData(key: 'userUid', value: user?.uid ?? '');
          await cacheHelper.saveData(
            key: 'userEmail',
            value: user?.email ?? '',
          );

          Get.offAllNamed(AppPages.home);

          Get.snackbar(
            "اهلاً بك",
            "تم تسجيل الدخول بنجاح",
            snackPosition: SnackPosition.BOTTOM,
          );
        },
      );
    } catch (e) {
      Get.snackbar("خطأ", e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  // تسجيل الدخول بواسطة Google
  Future<void> signInWithGoogle() async {
    try {
      isGoogleLoading.value = true;
      errorMessage.value = '';
      final result = await _signInWithGoogle();
      result.fold(
        (failure) {
          if (failure.statusCode == 400) {
            errorMessage.value = "الإيميل أو كلمة المرور غير صحيحة";
          } else if (failure.statusCode == 500) {
            errorMessage.value = "خطأ في الخادم، يرجى المحاولة لاحقًا";
          } else {
            errorMessage.value = failure.errMessage.isNotEmpty
                ? failure.errMessage
                : "حدث خطأ غير متوقع";
          }
          Get.snackbar(
            "خطأ",
            errorMessage.value,
            snackPosition: SnackPosition.BOTTOM,
          );
        },
        (user) async {
          currentUser.value = user;
          await cacheHelper.saveData(key: 'isLoggedIn', value: true);
          await cacheHelper.saveData(key: 'userUid', value: user?.uid ?? '');
          await cacheHelper.saveData(
            key: 'userEmail',
            value: user?.email ?? '',
          );
          final isVerified = await checkEmailVerification();

          if (isVerified) {
            Get.offAllNamed(AppPages.home);
            Get.snackbar("اهلاً بك", "تم تسجيل الدخول بنجاح");
          } else {
            Get.snackbar(
              "تحقق من بريدك",
              "يجب تأكيد الإيميل قبل المتابعة",
              backgroundColor: Colors.orange,
              colorText: Colors.white,
            );
          }
          Get.snackbar(
            "اهلاً بك",
            "تم تسجيل الدخول بنجاح",
            snackPosition: SnackPosition.BOTTOM,
          );
        },
      );
    } catch (e) {
      Get.snackbar("خطأ", e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isGoogleLoading.value = false;
    }
  }

  // تسجيل خروج
  Future<void> signOut() async {
    try {
      isLoading.value = true;
      final result = await _signOut();
      result.fold(
        (failure) => Get.snackbar(
          "خطأ",
          failure.errMessage,
          snackPosition: SnackPosition.BOTTOM,
        ),
        (_) async {
          currentUser.value = null;
          await cacheHelper.removeData(key: 'isLoggedIn');
          await cacheHelper.removeData(key: 'userUid');
          await cacheHelper.removeData(key: 'userEmail');
          Get.offAllNamed(AppPages.login);
        },
      );
    } catch (e) {
      Get.snackbar('خطأ', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  // إنشاء حساب جديد
  Future<void> signUpWithEmailAndPassword(
    String email,
    String password,
    String confirmPassword,
  ) async {
    if (!formKey_signUp.currentState!.validate()) {
      return;
    }

    if (password != confirmPassword) {
      Get.snackbar(
        "خطأ",
        "كلمتا السر غير متطابقتين",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      final username = usernameController.text.trim();
      final result = await _signUpWithEmailAndPassword(
        email,
        password,
        displayName: username.isNotEmpty ? username : null,
      );
      result.fold(
        (failure) {
          if (failure.statusCode == 400) {
            errorMessage.value = "الإيميل مستخدم مسبقًا";
          } else if (failure.statusCode == 500) {
            errorMessage.value = "خطأ في الخادم، يرجى المحاولة لاحقًا";
          } else {
            errorMessage.value = failure.errMessage.isNotEmpty
                ? failure.errMessage
                : "حدث خطأ غير متوقع";
          }
          Get.snackbar(
            "خطأ",
            errorMessage.value,
            snackPosition: SnackPosition.BOTTOM,
          );
        },
        (user) async {
          currentUser.value = user;
          await cacheHelper.saveData(key: 'isLoggedIn', value: true);
          await cacheHelper.saveData(key: 'userUid', value: user?.uid ?? '');
          await cacheHelper.saveData(
            key: 'userEmail',
            value: user?.email ?? '',
          );
          await sendEmailVerification();

          Get.offAllNamed(
            AppPages.verifyEmail,
            arguments: {
              'email': user?.email ?? '',
              'onResendVerification': sendEmailVerification,
              'onCheckVerification': () async {
                final isVerified = await checkEmailVerification();
                if (isVerified) {
                  Get.offAllNamed(AppPages.home);
                } else {
                  Get.snackbar(
                    "لم يتم التحقق",
                    "رجاءً قم بتأكيد بريدك قبل المتابعة",
                  );
                }
              },
              'onLogout': signOut,
            },
          );

          Get.snackbar(
            "تم إنشاء الحساب بنجاح!",
            "تم إرسال رابط التحقق إلى بريدك الإلكتروني",
            snackPosition: SnackPosition.BOTTOM,
          );
        },
      );
    } catch (e, stackTrace) {
      print('Sign up error: $e');
      print('Stack trace: $stackTrace');
      Get.snackbar(
        "خطأ في إنشاء الحساب",
        "حدث خطأ غير متوقع: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } finally {
      isLoading.value = false;
    }
  }

  // إرسال رابط إعادة تعيين كلمة المرور
  Future<void> sendPasswordResetEmail(String email) async {
    if (email.isEmpty) {
      Get.snackbar(
        "خطأ",
        "يرجى إدخال البريد الإلكتروني",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      final result = await _sendPasswordResetEmail(email);
      result.fold(
        (failure) {
          String message = "حدث خطأ أثناء إرسال رابط إعادة التعيين";
          if (failure.statusCode == 401) {
            message = "البريد الإلكتروني غير موجود";
          } else if (failure.statusCode == 400) {
            message = "البريد الإلكتروني غير صحيح";
          } else if (failure.errMessage.isNotEmpty) {
            message = failure.errMessage;
          }
          Get.snackbar("خطأ", message, snackPosition: SnackPosition.BOTTOM);
        },
        (_) {
          Get.snackbar(
            "تم الإرسال",
            "تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade300,
            colorText: Colors.white,
          );
        },
      );
    } catch (e) {
      Get.snackbar(
        "خطأ",
        "حدث خطأ غير متوقع: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // إرسال رابط التحقق من البريد الإلكتروني
  Future<void> sendEmailVerification() async {
    try {
      isLoading.value = true;
      final result = await _sendEmailVerification();
      result.fold(
        (failure) {
          Get.snackbar(
            "خطأ",
            failure.errMessage.isNotEmpty
                ? failure.errMessage
                : "فشل إرسال رابط التحقق",
            snackPosition: SnackPosition.BOTTOM,
          );
        },
        (_) {
          Get.snackbar(
            "تم الإرسال",
            "تم إرسال رابط التحقق إلى بريدك الإلكتروني",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade300,
            colorText: Colors.white,
          );
        },
      );
    } catch (e) {
      Get.snackbar(
        "خطأ",
        "حدث خطأ غير متوقع: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // التحقق من حالة التحقق من البريد الإلكتروني
  Future<bool> checkEmailVerification() async {
    try {
      final result = await _checkEmailVerification();
      return result.fold((failure) => false, (isVerified) => isVerified);
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    super.dispose();
    loginEmailController.dispose();
    loginPasswordController.dispose();
    signupEmailController.dispose();
    signupPasswordController.dispose();
    usernameController.dispose();
    confirmPasswordController.dispose();
  }
}
