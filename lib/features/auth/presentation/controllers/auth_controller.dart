import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:mata3mna/features/auth/domain/usecases/apply_email_verification_action_code.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/features/restaurant_info/data/services/restaurant_firestore_service.dart';
import 'package:mata3mna/features/dashboard/data/services/admin_firestore_service.dart';

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
  late final ApplyEmailVerificationActionCode _applyEmailVerificationActionCode;
  final RxString errorMessage = "".obs;

  RxBool isLoading = false.obs;
  RxBool isGoogleLoading = false.obs;
  final cacheHelper = Get.find<CacheHelper>();
  final RestaurantFirestoreService _restaurantService =
      Get.find<RestaurantFirestoreService>();

  final TextEditingController loginEmailController = TextEditingController();
  final TextEditingController loginPasswordController = TextEditingController();
  final TextEditingController signupEmailController = TextEditingController();
  final TextEditingController signupPasswordController =
      TextEditingController();

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  Rx<UserEntity?> currentUser = Rx<UserEntity?>(null);
  bool _isInitialCheck = true;

  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  @override
  void onInit() {
    super.onInit();
    _initializeUseCases();
    ever(currentUser, _handleAuthStateChange);
    _checkCurrentUser();
    syncUserRole();
    syncRestaurantInfoCompleted();
  }

  Future<void> syncUserRole() async {
    final uid = cacheHelper.getData(key: 'userUid');
    if (uid != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        await cacheHelper.saveData(key: 'userRole', value: userDoc['role']);
      }
    }
  }

  Future<void> syncRestaurantInfoCompleted() async {
    final uid = cacheHelper.getData(key: 'userUid') as String?;
    final email = cacheHelper.getData(key: 'userEmail') as String?;
    if (uid != null || (email != null && email.isNotEmpty)) {
      try {
        final isCompleted = await _restaurantService.getRestaurantInfoCompleted(
          ownerId: uid,
          ownerEmail: email,
        );
        await cacheHelper.saveData(
          key: 'restaurantInfoCompleted',
          value: isCompleted,
        );
      } catch (e) {
        await cacheHelper.saveData(
          key: 'restaurantInfoCompleted',
          value: false,
        );
      }
    }
  }

  void _handleAuthStateChange(UserEntity? user) async {
    if (user != null && user.uid != null) {
      // If role is not set yet, sync it first to prevent wrong routing
      var userRole = cacheHelper.getData(key: 'userRole') as String?;
      final previousRole = userRole; // Store previous role for comparison

      if (userRole == null) {
        // Role not synced yet, fetch it from Firestore
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            userRole = userDoc.data()?['role'] as String?;
            if (userRole != null) {
              await cacheHelper.saveData(key: 'userRole', value: userRole);
              print(
                '🔍 [AuthController] Synced role in _handleAuthStateChange: $userRole',
              );
            }
          }
        } catch (e) {
          print('Error syncing role in _handleAuthStateChange: $e');
        }
      }

      print(
        '🔍 [AuthController] _handleAuthStateChange - userRole: $userRole, uid: ${user.uid}, previousRole: $previousRole',
      );

      // CRITICAL: If admin was logged in and now we have an owner user,
      // this means admin created a new owner account. Sign out and redirect to admin login!
      final currentRoute = Get.currentRoute;
      final isOnAdminRoute =
          currentRoute == AppPages.dashboard ||
          currentRoute == AppPages.adminRestaurantManagement ||
          currentRoute == AppPages.adminItemManagement ||
          currentRoute == AppPages.adminCategoryManagement ||
          currentRoute == AppPages.locationManagement;

      // Check if we're on an admin route and the new user is an owner
      // This indicates admin created a new owner account
      // BUT: If admin session was restored, we should NOT redirect
      // Check if admin is already signed in (session was restored)
      final currentAuthUser = FirebaseAuth.instance.currentUser;
      String? currentUserRole;
      if (currentAuthUser != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentAuthUser.uid)
              .get();
          currentUserRole = userDoc.data()?['role'] as String?;
        } catch (e) {
          print('Error checking current user role: $e');
        }
      }

      // If admin is already signed in, don't redirect
      if (currentUserRole == 'admin' && isOnAdminRoute) {
        print(
          '🔍 [AuthController] Admin session was restored. No redirect needed.',
        );
        // Admin is already signed in, just sign out the owner that was created
        if (userRole == 'owner') {
          try {
            await _authRepository.signOut();
            print(
              '🔍 [AuthController] Signed out created owner. Admin session preserved.',
            );
          } catch (e) {
            print('Error signing out created owner: $e');
          }
        }
        return; // Don't redirect, admin is already logged in
      }

      if (userRole == 'owner' && isOnAdminRoute) {
        // Additional check: if previous role was admin, or if we're definitely on admin route
        // (admin wouldn't navigate to owner routes)
        if (previousRole == 'admin' || isOnAdminRoute) {
          print(
            '🔍 [AuthController] Admin created owner account - signing out and redirecting to admin login',
          );
          // Sign out the newly created owner user
          // Clear cache to reset role
          await cacheHelper.saveData(key: 'userRole', value: null);
          await cacheHelper.saveData(key: 'isLoggedIn', value: false);
          try {
            await _authRepository.signOut();
            // Show message and redirect to admin login
            Get.offAllNamed(AppPages.adminLogin);
            Get.snackbar(
              'تم إنشاء حساب المالك',
              'تم إنشاء حساب المالك بنجاح. يرجى تسجيل الدخول مرة أخرى كمسؤول.',
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 4),
              maxWidth: Get.width > 1200
                  ? 400.0
                  : (Get.width > 768 ? 350.0 : null),
              margin: Get.width > 768
                  ? EdgeInsets.symmetric(
                      horizontal: Get.width > 1200
                          ? (Get.width - 400.0) / 2
                          : (Get.width - 350.0) / 2,
                      vertical: 16,
                    )
                  : EdgeInsets.all(16),
              snackStyle: SnackStyle.FLOATING,
              borderRadius: 12,
            );
            return;
          } catch (e) {
            print('Error signing out after admin created user: $e');
            // Still redirect to admin login even if signout fails
            Get.offAllNamed(AppPages.adminLogin);
            return;
          }
        }
      }

      // Check user role and navigate accordingly - no email verification required
      String targetRoute;
      if (userRole == 'customer') {
        targetRoute = AppPages.customerView;
      } else if (userRole == 'admin') {
        targetRoute = AppPages.dashboard;
      } else {
        // For owners or if role is null, check _ownerNextRoute
        // But add extra check: if role is null, don't route to restaurant info
        targetRoute = await _ownerNextRoute();
      }

      print('🔍 [AuthController] Navigating to: $targetRoute');

      // Only navigate if not on initial check and not already on target route
      // During initial check, let the app's initialRoute handle navigation
      // Skip navigation if we're on login/admin-login pages (login flow will handle navigation)
      if (!_isInitialCheck &&
          currentRoute != targetRoute &&
          currentRoute != AppPages.adminLogin &&
          currentRoute != AppPages.login) {
        // Add a small delay to ensure GetMaterialApp is ready
        await Future.delayed(const Duration(milliseconds: 100));
        if (Get.key.currentContext != null) {
          print(
            '🔍 [AuthController] _handleAuthStateChange - navigating to: $targetRoute',
          );
          Get.offAllNamed(targetRoute);
        }
      } else {
        print(
          '🔍 [AuthController] _handleAuthStateChange - skipping navigation. isInitialCheck: $_isInitialCheck, currentRoute: $currentRoute, targetRoute: $targetRoute',
        );
      }
      // Mark initial check as complete after first run
      _isInitialCheck = false;
    } else {
      // If user is null, mark initial check as complete
      _isInitialCheck = false;
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
          _isInitialCheck = false;
        },
        (user) async {
          if (user != null && user.uid != null) {
            // تحديث البيانات المحلية
            await cacheHelper.saveData(key: 'isLoggedIn', value: true);
            await cacheHelper.saveData(key: 'userUid', value: user.uid ?? '');
            await cacheHelper.saveData(
              key: 'userEmail',
              value: user.email ?? '',
            );

            // Sync user role from Firestore BEFORE setting currentUser
            // This prevents _handleAuthStateChange from routing with wrong role
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

            if (userDoc.exists) {
              final role = userDoc.data()?['role'] as String?;
              if (role != null) {
                await cacheHelper.saveData(key: 'userRole', value: role);
              }
            }

            // Sync restaurant info completion from Firestore
            if (user.uid != null) {
              await syncRestaurantInfoCompleted();
            }

            // Now set currentUser AFTER role is synced
            currentUser.value = user;
            _isInitialCheck = false;
          } else {
            currentUser.value = null;
            await cacheHelper.removeData(key: 'isLoggedIn');
            await cacheHelper.removeData(key: 'userUid');
            await cacheHelper.removeData(key: 'userEmail');
            _isInitialCheck = false;
          }
          // Mark initial check as complete after checking
          // The _handleAuthStateChange will handle navigation
        },
      );
    } catch (e) {
      print('Error checking current user: $e');
      currentUser.value = null;
      _isInitialCheck = false;
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
    _applyEmailVerificationActionCode = ApplyEmailVerificationActionCode(
      _authRepository,
    );
  }

  // تسجيل الدخول بالبريد
  Future<void> signInWithEmail(
    String email,
    String password,
    GlobalKey<FormState> formKey, {
    bool rememberMe = false,
  }) async {
    if (!formKey.currentState!.validate()) {
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
          // Save user data first
          await cacheHelper.saveData(key: 'isLoggedIn', value: true);
          await cacheHelper.saveData(key: 'userUid', value: user?.uid ?? '');
          await cacheHelper.saveData(
            key: 'userEmail',
            value: user?.email ?? '',
          );

          // Fetch and save user role from Firestore BEFORE setting currentUser
          // This prevents _handleAuthStateChange from routing with wrong role
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .get();

          if (userDoc.exists) {
            final role = userDoc['role'] as String?;
            if (role != null) {
              await cacheHelper.saveData(key: 'userRole', value: role);
              print('🔍 [AuthController] Found role in Firestore: $role');

              // Store admin password if this is an admin login
              // This allows us to restore admin session when creating owner accounts
              if (role == 'admin') {
                AdminFirestoreService.storeAdminPassword(password);
                print(
                  '🔍 [AuthController] Admin password stored for session restoration',
                );

                // Save remember me preference for admin
                if (rememberMe) {
                  await cacheHelper.saveData(
                    key: 'admin_remember_me',
                    value: true,
                  );
                  await cacheHelper.saveData(
                    key: 'admin_remembered_email',
                    value: email,
                  );
                } else {
                  await cacheHelper.removeData(key: 'admin_remember_me');
                  await cacheHelper.removeData(key: 'admin_remembered_email');
                }
              }
            } else {
              print(
                '🔍 [AuthController] User document exists but role is null. Checking for restaurant...',
              );
              // Role is null, check if user has a restaurant (admin-created owners)
              final hasRestaurant = await _restaurantService
                  .getRestaurantInfoCompleted(
                    ownerId: user?.uid,
                    ownerEmail: user?.email,
                  );
              if (hasRestaurant) {
                // User has a restaurant, they should be an owner
                final ownerRole = 'owner';
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .update({'role': ownerRole});
                await cacheHelper.saveData(key: 'userRole', value: ownerRole);
                print(
                  '🔍 [AuthController] User has restaurant, set role to owner',
                );
              }
            }
          } else {
            // If user document doesn't exist, check if they have a restaurant first
            // This handles cases where admin created restaurant but Firestore user doc wasn't created
            print(
              '🔍 [AuthController] User document does not exist. Checking for restaurant...',
            );
            bool hasRestaurant = false;
            try {
              hasRestaurant = await _restaurantService
                  .getRestaurantInfoCompleted(
                    ownerId: user?.uid,
                    ownerEmail: user?.email,
                  );
            } catch (e) {
              print('🔍 [AuthController] Error checking restaurant: $e');
            }

            // If user has a restaurant, they're an owner; otherwise default to customer
            final defaultRole = hasRestaurant ? 'owner' : 'customer';
            print(
              '🔍 [AuthController] Creating user document with role: $defaultRole (hasRestaurant: $hasRestaurant)',
            );

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .set({
                  'role': defaultRole,
                  'email': user?.email,
                  'displayName': user?.displayName,
                  'createdAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            await cacheHelper.saveData(key: 'userRole', value: defaultRole);
          }

          // Sync restaurant info completion status from Firestore
          if (user?.uid != null) {
            await syncRestaurantInfoCompleted();
          }

          // Double-check role is set
          var finalRole = cacheHelper.getData(key: 'userRole') as String?;
          if (finalRole == null) {
            // Role still not set, fetch again
            final userDocCheck = await FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .get();
            if (userDocCheck.exists) {
              finalRole = userDocCheck.data()?['role'] as String?;
              if (finalRole != null) {
                await cacheHelper.saveData(key: 'userRole', value: finalRole);
              }
            }
          }

          print(
            '🔍 [AuthController] signInWithEmail - finalRole: $finalRole, uid: ${user?.uid}',
          );

          // Navigate directly based on user role BEFORE setting currentUser
          // This prevents _handleAuthStateChange from interfering
          final targetRoute = finalRole == 'customer'
              ? AppPages.customerView
              : finalRole == 'admin'
              ? AppPages.dashboard
              : await _ownerNextRoute();

          print(
            '🔍 [AuthController] signInWithEmail - navigating to: $targetRoute',
          );

          // Navigate first, then set currentUser to prevent _handleAuthStateChange from overriding
          Get.offAllNamed(targetRoute);

          // Now set currentUser AFTER navigation
          currentUser.value = user;

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
          // Save user data first
          await cacheHelper.saveData(key: 'isLoggedIn', value: true);
          await cacheHelper.saveData(key: 'userUid', value: user?.uid ?? '');
          await cacheHelper.saveData(
            key: 'userEmail',
            value: user?.email ?? '',
          );

          // Fetch and save user role from Firestore BEFORE setting currentUser
          // This prevents _handleAuthStateChange from routing with wrong role
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .get();

          if (userDoc.exists) {
            final role = userDoc['role'] as String?;
            if (role != null) {
              await cacheHelper.saveData(key: 'userRole', value: role);
            }
          } else {
            // If user document doesn't exist, create it with default role
            final defaultRole = 'owner';
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .set({
                  'role': defaultRole,
                  'email': user?.email,
                  'displayName': user?.displayName,
                  'createdAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            await cacheHelper.saveData(key: 'userRole', value: defaultRole);
          }

          // Sync restaurant info completion status from Firestore
          if (user?.uid != null) {
            await syncRestaurantInfoCompleted();
          }

          // Double-check role is set
          var finalRole = cacheHelper.getData(key: 'userRole') as String?;
          if (finalRole == null) {
            // Role still not set, fetch again
            final userDocCheck = await FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .get();
            if (userDocCheck.exists) {
              finalRole = userDocCheck.data()?['role'] as String?;
              if (finalRole != null) {
                await cacheHelper.saveData(key: 'userRole', value: finalRole);
              }
            }
          }

          print(
            '🔍 [AuthController] signInWithGoogle - finalRole: $finalRole, uid: ${user?.uid}',
          );

          // Navigate directly based on user role BEFORE setting currentUser
          // This prevents _handleAuthStateChange from interfering
          final targetRoute = finalRole == 'customer'
              ? AppPages.customerView
              : finalRole == 'admin'
              ? AppPages.dashboard
              : await _ownerNextRoute();

          print(
            '🔍 [AuthController] signInWithGoogle - navigating to: $targetRoute',
          );

          // Navigate first, then set currentUser to prevent _handleAuthStateChange from overriding
          Get.offAllNamed(targetRoute);

          // Now set currentUser AFTER navigation
          currentUser.value = user;

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
      // Clear stored admin password on logout
      AdminFirestoreService.clearStoredAdminPassword();

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
          await cacheHelper.removeData(key: 'userRole');
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
    GlobalKey<FormState> formKey_signUp,
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

          // Check if email was registered before (check if user document exists)
          bool isNewUser = true;
          if (user?.email != null) {
            try {
              // Check if any user document exists with this email
              final usersQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: user?.email)
                  .limit(1)
                  .get();

              // Also check if user document exists by UID (in case email wasn't set before)
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .get();

              isNewUser = usersQuery.docs.isEmpty && !userDoc.exists;
            } catch (e) {
              // If check fails, assume new user
              isNewUser = true;
            }
          }

          // Get role from cache (set in start_page) or default to owner
          final role =
              cacheHelper.getData(key: 'userRole') as String? ?? 'owner';

          // Save role to Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .set({
                'role': role,
                'email': user?.email,
                'displayName': user?.displayName,
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

          // Ensure cache has the role
          await cacheHelper.saveData(key: 'userRole', value: role);

          // If new user, mark restaurant info as not completed
          if (isNewUser) {
            await cacheHelper.saveData(
              key: 'restaurantInfoCompleted',
              value: false,
            );
          } else {
            // For existing users, sync restaurant info completion status
            if (user?.uid != null) {
              await syncRestaurantInfoCompleted();
            }
          }

          // Send email verification after signup
          await sendEmailVerification();

          // Show verify email screen only once after signup
          Get.offAllNamed(
            AppPages.verifyEmail,
            arguments: {
              'email': user?.email ?? '',
              'onResendVerification': sendEmailVerification,
              'onCheckVerification': () async {
                final isVerified = await checkEmailVerification();
                if (isVerified) {
                  // For new users, show complete restaurant info screen
                  // For existing users, go to their normal route
                  final userRole =
                      cacheHelper.getData(key: 'userRole') as String?;

                  String targetRoute;
                  if (userRole == 'customer') {
                    targetRoute = AppPages.customerView;
                  } else if (userRole == 'admin') {
                    targetRoute = AppPages.dashboard;
                  } else {
                    // For owners: if new user, show complete info screen, otherwise check completion
                    if (isNewUser) {
                      targetRoute = AppPages.completeRestaurantInfo;
                    } else {
                      // Sync restaurant info completion status from Firestore
                      if (user?.uid != null) {
                        await syncRestaurantInfoCompleted();
                      }
                      targetRoute = await _ownerNextRoute();
                    }
                  }

                  Get.offAllNamed(targetRoute);
                } else {
                  // Check if user is logged in
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) {
                    // User is not logged in - they might have verified on another device
                    Get.snackbar(
                      "لم يتم تسجيل الدخول",
                      "إذا قمت بالتحقق من بريدك على جهاز آخر، يرجى تسجيل الدخول أولاً",
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 5),
                    );
                    // Navigate to login page
                    Get.offAllNamed(AppPages.login);
                  } else {
                    // User is logged in but email not verified
                    Get.snackbar(
                      "لم يتم التحقق",
                      "رجاءً قم بتأكيد بريدك قبل المتابعة. تأكد من النقر على رابط التحقق في البريد الإلكتروني",
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 5),
                    );
                  }
                }
              },
              'onLogout': signOut,
            },
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

  // Handle email verification action code from deep link
  Future<bool> handleEmailVerificationLink(String url) async {
    try {
      // Extract action code from URL
      // Firebase email verification links have format:
      // https://[project].firebaseapp.com/__/auth/action?mode=verifyEmail&oobCode=[code]&continueUrl=...
      final uri = Uri.parse(url);
      final actionCode = uri.queryParameters['oobCode'];

      if (actionCode == null || actionCode.isEmpty) {
        print('No action code found in URL: $url');
        return false;
      }

      print('Applying email verification action code...');
      final result = await _applyEmailVerificationActionCode(actionCode);

      return result.fold(
        (failure) {
          print('Failed to apply action code: ${failure.errMessage}');
          Get.snackbar(
            "خطأ في التحقق",
            failure.errMessage,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade300,
            colorText: Colors.white,
          );
          return false;
        },
        (_) {
          print('Email verification successful!');
          Get.snackbar(
            "تم التحقق",
            "تم التحقق من بريدك الإلكتروني بنجاح",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade300,
            colorText: Colors.white,
          );
          return true;
        },
      );
    } catch (e) {
      print('Error handling verification link: $e');
      Get.snackbar(
        "خطأ",
        "حدث خطأ أثناء معالجة رابط التحقق: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade300,
        colorText: Colors.white,
      );
      return false;
    }
  }

  // Extract action code from URL (helper method)
  String? extractActionCodeFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['oobCode'];
    } catch (e) {
      print('Error extracting action code: $e');
      return null;
    }
  }

  Future<String> _ownerNextRoute() async {
    // Check if user is admin first - admins should always go to dashboard
    var userRole = cacheHelper.getData(key: 'userRole') as String?;

    print('🔍 [AuthController] _ownerNextRoute - initial userRole: $userRole');

    // If role is not set, try to fetch it from Firestore
    if (userRole == null) {
      final uid = cacheHelper.getData(key: 'userUid') as String?;
      if (uid != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

          if (userDoc.exists) {
            userRole = userDoc.data()?['role'] as String?;
            print('🔍 [AuthController] Fetched role from Firestore: $userRole');
            if (userRole != null) {
              await cacheHelper.saveData(key: 'userRole', value: userRole);
            }
          }
        } catch (e) {
          print('Error fetching role in _ownerNextRoute: $e');
        }
      }
    }

    // If still admin after checking, return dashboard
    if (userRole == 'admin') {
      print('🔍 [AuthController] User is admin, returning dashboard');
      return AppPages.dashboard;
    }

    final uid = cacheHelper.getData(key: 'userUid') as String?;
    final email = cacheHelper.getData(key: 'userEmail') as String?;

    // Double-check: if role is still null or admin, return dashboard
    // This is a safety check in case role wasn't synced properly
    if (userRole == null || userRole == 'admin') {
      print(
        '🔍 [AuthController] Role is null or admin, returning dashboard as fallback',
      );
      return AppPages.dashboard;
    }

    print(
      '🔍 [AuthController] User is owner, checking restaurant info completion',
    );
    print('🔍 [AuthController] Owner UID: $uid, Email: $email');

    if (uid != null || (email != null && email.isNotEmpty)) {
      try {
        print(
          '🔍 [AuthController] Calling getRestaurantInfoCompleted with ownerId: $uid, ownerEmail: $email',
        );
        final isCompleted = await _restaurantService.getRestaurantInfoCompleted(
          ownerId: uid,
          ownerEmail: email,
        );
        print('🔍 [AuthController] Restaurant info completed: $isCompleted');
        await cacheHelper.saveData(
          key: 'restaurantInfoCompleted',
          value: isCompleted,
        );
        final targetRoute = isCompleted
            ? AppPages.home
            : AppPages.completeRestaurantInfo;
        print('🔍 [AuthController] Navigating to: $targetRoute');
        return targetRoute;
      } catch (e) {
        print('🔍 [AuthController] ERROR checking restaurant info: $e');
        final isCompleted =
            await cacheHelper.getData(key: 'restaurantInfoCompleted')
                as bool? ??
            false;
        print('🔍 [AuthController] Using cached value: $isCompleted');
        return isCompleted ? AppPages.home : AppPages.completeRestaurantInfo;
      }
    }
    final isCompleted =
        cacheHelper.getData(key: 'restaurantInfoCompleted') as bool? ?? false;
    return isCompleted ? AppPages.home : AppPages.completeRestaurantInfo;
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
