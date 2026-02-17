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
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final RestaurantSupabaseService _restaurantService =
      Get.find<RestaurantSupabaseService>();

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
    _listenToSupabaseAuthState();
  }

  // Listen to Supabase auth state changes
  void _listenToSupabaseAuthState() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      print('[AuthController] Supabase auth state changed: $event');

      if ((event == AuthChangeEvent.initialSession ||
              event == AuthChangeEvent.signedIn) &&
          session != null) {
        // Session restored on app start or user signed in: persist login to cache
        final user = session.user;
        final userEntity = UserEntity(
          uid: user.id,
          email: user.email,
          displayName:
              user.userMetadata?['display_name'] as String? ??
              user.userMetadata?['full_name'] as String?,
        );
        currentUser.value = userEntity;
        await cacheHelper.saveData(key: 'isLoggedIn', value: true);
        await cacheHelper.saveData(key: 'userUid', value: user.id);
        await cacheHelper.saveData(
            key: 'userEmail', value: user.email ?? '');
        if (event == AuthChangeEvent.initialSession) {
          await syncUserRole();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        // User signed out
        currentUser.value = null;
      } else if (event == AuthChangeEvent.tokenRefreshed && session != null) {
        // Token refreshed - update user
        final user = session.user;
        final userEntity = UserEntity(
          uid: user.id,
          email: user.email,
          displayName:
              user.userMetadata?['display_name'] as String? ??
              user.userMetadata?['full_name'] as String?,
        );
        currentUser.value = userEntity;
      }
    });
  }

  Future<void> syncUserRole() async {
    final uid = cacheHelper.getData(key: 'userUid');
    if (uid != null) {
      try {
        final userDoc = await Supabase.instance.client
            .from('users')
            .select('*')
            .eq('id', uid)
            .maybeSingle();
        if (userDoc != null) {
          await cacheHelper.saveData(key: 'userRole', value: userDoc['role']);
        }
      } catch (e) {
        print('Error fetching user role: $e');
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
          final userDoc = await Supabase.instance.client
              .from('users')
              .select('*')
              .eq('id', user.uid ?? '')
              .maybeSingle();

          if (userDoc != null) {
            userRole = userDoc['role'] as String?;
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
      final currentAuthUser = Supabase.instance.client.auth.currentUser;
      String? currentUserRole;
      if (currentAuthUser != null) {
        try {
          final userDoc = await Supabase.instance.client
              .from('users')
              .select('*')
              .eq('id', currentAuthUser.id)
              .maybeSingle();
          currentUserRole = userDoc?['role'] as String?;
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
      // Skip navigation if we're on login pages (login flow will handle navigation)
      // BUT: Allow navigation from admin-login if user is admin (they just logged in)
      // Also skip navigation if we're on root/start page (user is choosing role)
      final shouldNavigateFromAdminLogin =
          currentRoute == AppPages.adminLogin && userRole == 'admin';

      if (!_isInitialCheck &&
          currentRoute != targetRoute &&
          !shouldNavigateFromAdminLogin &&
          currentRoute != AppPages.login &&
          currentRoute != AppPages.root) {
        // Add a small delay to ensure GetMaterialApp is ready
        await Future.delayed(const Duration(milliseconds: 100));
        if (Get.key.currentContext != null) {
          print(
            '🔍 [AuthController] _handleAuthStateChange - navigating to: $targetRoute',
          );
          Get.offAllNamed(targetRoute);
        }
      } else if (shouldNavigateFromAdminLogin) {
        // Special case: navigate from admin-login to dashboard for admin users
        print(
          '🔍 [AuthController] _handleAuthStateChange - navigating from admin-login to dashboard for admin user',
        );
        await Future.delayed(const Duration(milliseconds: 100));
        if (Get.key.currentContext != null) {
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

            // Sync user role from Supabase BEFORE setting currentUser
            // This prevents _handleAuthStateChange from routing with wrong role
            try {
              final userDoc = await Supabase.instance.client
                  .from('users')
                  .select('*')
                  .eq('id', user.uid ?? '')
                  .maybeSingle();

              if (userDoc != null) {
                final role = userDoc['role'] as String?;
                if (role != null) {
                  await cacheHelper.saveData(key: 'userRole', value: role);
                }
              }
            } catch (e) {
              // Network error (e.g. Connection closed) - use cached role or default
              print('[AuthController] Error fetching user role: $e');
              final cachedRole = cacheHelper.getData(key: 'userRole') as String?;
              if (cachedRole == null) {
                await cacheHelper.saveData(key: 'userRole', value: 'owner');
              }
            }

            // Sync restaurant info completion from Firestore
            try {
              if (user.uid != null) {
                await syncRestaurantInfoCompleted();
              }
            } catch (e) {
              print('[AuthController] Error syncing restaurant info: $e');
              await cacheHelper.saveData(key: 'restaurantInfoCompleted', value: false);
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
    bool isAdminLogin = false,
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
          // Check if user document exists in Supabase FIRST
          // If it doesn't exist, the account was deleted (restaurant was deleted)
          var userDoc = await Supabase.instance.client
              .from('users')
              .select('*')
              .eq('id', user?.uid ?? '')
              .maybeSingle();

          // First login / replication: retry once after short delay
          if (userDoc == null) {
            await Future.delayed(const Duration(milliseconds: 300));
            userDoc = await Supabase.instance.client
                .from('users')
                .select('*')
                .eq('id', user?.uid ?? '')
                .maybeSingle();
          }

          if (userDoc == null) {
            // User document doesn't exist - check if this is admin login
            // Use explicit flag from AdminLoginPage; when using home: AdminLoginPage() route may be "/" not /admin-login
            final currentRoute = Get.currentRoute;
            final isAdminLoginContext =
                isAdminLogin || currentRoute == AppPages.adminLogin;

            if (isAdminLoginContext) {
              // This is admin login - create user document with admin role
              print(
                '🔍 [AuthController] User document does not exist. Creating admin user document...',
              );

              try {
                final userData = {
                  'id': user?.uid ?? '',
                  'email': user?.email ?? '',
                  'password':
                      password, // Password is required by the users table
                  'role': 'admin',
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                };

                // Try to insert, but handle duplicate key or RLS errors gracefully
                bool userDocExists = false;
                try {
                  await Supabase.instance.client.from('users').insert(userData);
                  print(
                    '🔍 [AuthController] Admin user document created successfully',
                  );
                  userDocExists = true;
                } catch (insertError) {
                  final errorMessage = insertError.toString();
                  final errorCode = insertError is Exception
                      ? (insertError.toString().contains('42501')
                            ? '42501'
                            : insertError.toString().contains('23505')
                            ? '23505'
                            : null)
                      : null;

                  // Handle duplicate key error (user already exists)
                  if (errorCode == '23505' ||
                      errorMessage.contains('duplicate key') ||
                      errorMessage.contains('unique constraint')) {
                    print(
                      '🔍 [AuthController] User document already exists (duplicate key), this is fine - will fetch it',
                    );
                    // User already exists, this is fine - we'll fetch it below
                    userDocExists =
                        true; // Mark as exists so we don't treat it as an error
                  } else if (errorCode == '42501' ||
                      errorMessage.contains('row-level security') ||
                      errorMessage.contains('policy') ||
                      errorMessage.contains('RLS')) {
                    // RLS blocked the insert, try upsert instead
                    print(
                      '🔍 [AuthController] RLS blocked insert, trying upsert...',
                    );
                    try {
                      await Supabase.instance.client
                          .from('users')
                          .upsert(userData, onConflict: 'id');
                      print(
                        '🔍 [AuthController] Admin user document created via upsert',
                      );
                      userDocExists = true;
                    } catch (upsertError) {
                      // If upsert also fails, check if it's a duplicate key
                      final upsertErrorMsg = upsertError.toString();
                      if (upsertErrorMsg.contains('duplicate key') ||
                          upsertErrorMsg.contains('unique constraint')) {
                        print(
                          '🔍 [AuthController] User document already exists (from upsert), this is fine',
                        );
                        // User already exists, this is fine
                        userDocExists = true;
                      } else {
                        print(
                          '🔍 [AuthController] Upsert also failed: $upsertError',
                        );
                        // Only rethrow if it's not a duplicate key error
                        rethrow;
                      }
                    }
                  } else {
                    // Other error, rethrow only if it's not a duplicate key
                    if (!errorMessage.contains('duplicate key') &&
                        !errorMessage.contains('unique constraint')) {
                      print(
                        '🔍 [AuthController] Unexpected error during insert: $insertError',
                      );
                      rethrow;
                    } else {
                      // It's a duplicate key error in a different format
                      userDocExists = true;
                    }
                  }
                }

                // Only continue if user document exists (created or already existed)
                if (!userDocExists) {
                  throw Exception('Failed to create or verify user document');
                }

                // Fetch the user document (either newly created or already existing)
                // Add retry logic in case of timing issues or RLS delays
                Map<String, dynamic>? fetchedUserDoc;
                for (int attempt = 0; attempt < 3; attempt++) {
                  try {
                    fetchedUserDoc = await Supabase.instance.client
                        .from('users')
                        .select('*')
                        .eq('id', user?.uid ?? '')
                        .maybeSingle();

                    if (fetchedUserDoc != null) {
                      break; // Success, exit retry loop
                    }

                    if (attempt < 2) {
                      // Wait before retrying (exponential backoff)
                      await Future.delayed(
                        Duration(milliseconds: 200 * (attempt + 1)),
                      );
                      print(
                        '🔍 [AuthController] Retrying fetch user document (attempt ${attempt + 2}/3)...',
                      );
                    }
                  } catch (fetchError) {
                    print(
                      '🔍 [AuthController] Error fetching user document (attempt ${attempt + 1}): $fetchError',
                    );
                    if (attempt < 2) {
                      await Future.delayed(
                        Duration(milliseconds: 200 * (attempt + 1)),
                      );
                    } else {
                      // Last attempt failed, rethrow
                      rethrow;
                    }
                  }
                }

                if (fetchedUserDoc == null) {
                  // If we still can't fetch, try one more time with a longer delay
                  print(
                    '🔍 [AuthController] User document still not found, trying one final fetch...',
                  );
                  await Future.delayed(const Duration(milliseconds: 500));
                  try {
                    fetchedUserDoc = await Supabase.instance.client
                        .from('users')
                        .select('*')
                        .eq('id', user?.uid ?? '')
                        .maybeSingle();
                  } catch (e) {
                    print('🔍 [AuthController] Final fetch also failed: $e');
                  }
                }

                if (fetchedUserDoc == null) {
                  // If we still can't fetch the document (likely RLS issue),
                  // create a minimal userDoc from the data we have
                  // This allows the login to continue
                  print(
                    '🔍 [AuthController] Could not fetch user document (likely RLS), using fallback data',
                  );
                  userDoc = {
                    'id': user?.uid ?? '',
                    'email': user?.email ?? '',
                    'role':
                        'admin', // We know this is admin since we just created it
                  };
                  print(
                    '🔍 [AuthController] Using fallback user document with admin role',
                  );
                } else {
                  // Set userDoc to continue with normal flow
                  userDoc = fetchedUserDoc;
                  print(
                    '🔍 [AuthController] User document ready (role: ${fetchedUserDoc['role']})',
                  );
                }

                // Set role in cache
                await cacheHelper.saveData(key: 'userRole', value: 'admin');

                // Store admin password for session restoration
                AdminFirestoreService.storeAdminPassword(password);

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

                // userDoc is already set above, no need to fetch again
              } catch (e) {
                final errorMsg = e.toString();
                // Check if it's a duplicate key error (user already exists)
                if (errorMsg.contains('duplicate key') ||
                    errorMsg.contains('unique constraint') ||
                    errorMsg.contains('23505')) {
                  print(
                    '🔍 [AuthController] User document already exists (duplicate key), fetching existing document...',
                  );
                  // User already exists, fetch it and continue
                  try {
                    final existingUserDoc = await Supabase.instance.client
                        .from('users')
                        .select('*')
                        .eq('id', user?.uid ?? '')
                        .maybeSingle();

                    if (existingUserDoc != null) {
                      userDoc = existingUserDoc;
                      // Set role in cache
                      await cacheHelper.saveData(
                        key: 'userRole',
                        value: 'admin',
                      );
                      // Store admin password for session restoration
                      AdminFirestoreService.storeAdminPassword(password);
                      print(
                        '🔍 [AuthController] Fetched existing admin user document successfully',
                      );
                      // Continue with normal flow - don't return
                    } else {
                      // Couldn't fetch existing doc, sign out
                      await _authRepository.signOut();
                      errorMessage.value = "فشل في جلب بيانات المسؤول";
                      isLoading.value = false;
                      Get.snackbar(
                        "خطأ",
                        errorMessage.value,
                        snackPosition: SnackPosition.BOTTOM,
                      );
                      return;
                    }
                  } catch (fetchError) {
                    print(
                      '🔍 [AuthController] Error fetching existing user document: $fetchError',
                    );
                    await _authRepository.signOut();
                    errorMessage.value = "فشل في جلب بيانات المسؤول";
                    isLoading.value = false;
                    Get.snackbar(
                      "خطأ",
                      errorMessage.value,
                      snackPosition: SnackPosition.BOTTOM,
                    );
                    return;
                  }
                } else {
                  // Other error, sign out and show error
                  print(
                    '🔍 [AuthController] Error creating admin user document: $e',
                  );
                  await _authRepository.signOut();
                  errorMessage.value = "فشل في إنشاء حساب المسؤول";
                  isLoading.value = false;
                  Get.snackbar(
                    "خطأ",
                    errorMessage.value,
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }
              }
            } else {
              // Mobile owner login: row may exist but RLS blocks SELECT (e.g. missing "read own row" policy)
              final cachedRole =
                  cacheHelper.getData(key: 'userRole') as String?;
              if (cachedRole == 'owner') {
                print(
                  '🔍 [AuthController] User document not found (RLS?). Using cached owner role and continuing.',
                );
                await cacheHelper.saveData(key: 'isLoggedIn', value: true);
                await cacheHelper.saveData(
                  key: 'userUid',
                  value: user?.uid ?? '',
                );
                await cacheHelper.saveData(
                  key: 'userEmail',
                  value: user?.email ?? '',
                );
                await cacheHelper.saveData(key: 'userRole', value: 'owner');
                if (user?.uid != null) {
                  await syncRestaurantInfoCompleted();
                }
                final targetRoute = await _ownerNextRoute();
                currentUser.value = user;
                await Future.delayed(const Duration(milliseconds: 100));
                Get.offAllNamed(targetRoute);
                Get.snackbar(
                  "اهلاً بك",
                  "تم تسجيل الدخول بنجاح",
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              // Not owner flow - account was deleted or doesn't exist
              print(
                '🔍 [AuthController] User document does not exist - account was deleted',
              );
              await _authRepository.signOut();
              errorMessage.value =
                  "الحساب غير موجود، لازم تعمل إنشاء حساب جديد";
              isLoading.value = false;
              Get.snackbar(
                "خطأ",
                errorMessage.value,
                snackPosition: SnackPosition.BOTTOM,
              );
              return;
            }
          }

          // Save user data first
          await cacheHelper.saveData(key: 'isLoggedIn', value: true);
          await cacheHelper.saveData(key: 'userUid', value: user?.uid ?? '');
          await cacheHelper.saveData(
            key: 'userEmail',
            value: user?.email ?? '',
          );

          // Fetch and save user role from Supabase BEFORE setting currentUser
          // This prevents _handleAuthStateChange from routing with wrong role
          final role = userDoc['role'] as String?;
          if (role != null && role.isNotEmpty) {
            await cacheHelper.saveData(key: 'userRole', value: role);
            print('🔍 [AuthController] Found role in Supabase: $role');

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
            // Role is null: check if user has a restaurant (admin-created owners)
            final restaurantInfo = await _restaurantService
                .getRestaurantByOwnerId(user!.uid ?? '');
            if (restaurantInfo != null) {
              final ownerRole = 'owner';
              try {
                await Supabase.instance.client
                    .from('users')
                    .update({'role': ownerRole})
                    .eq('id', user.uid ?? '');
              } catch (_) {}
              await cacheHelper.saveData(key: 'userRole', value: ownerRole);
              print(
                '🔍 [AuthController] User has restaurant, set role to owner',
              );
            } else {
              // No restaurant: use cached role (mobile owner came from start page with role=owner)
              final cachedRole =
                  cacheHelper.getData(key: 'userRole') as String?;
              if (cachedRole == 'owner') {
                await cacheHelper.saveData(key: 'userRole', value: 'owner');
                print(
                  '🔍 [AuthController] Role null in DB, using cached owner (mobile login)',
                );
              }
            }
          }

          // Sync restaurant info completion status from Firestore
          if (user?.uid != null) {
            await syncRestaurantInfoCompleted();
          }

          // Double-check role is set (mobile owner may have role only in cache)
          var finalRole = cacheHelper.getData(key: 'userRole') as String?;
          if (finalRole == null) {
            final userDocCheck = await Supabase.instance.client
                .from('users')
                .select('*')
                .eq('id', user?.uid ?? '')
                .maybeSingle();
            if (userDocCheck != null) {
              finalRole = userDocCheck['role'] as String?;
              if (finalRole != null) {
                await cacheHelper.saveData(key: 'userRole', value: finalRole);
              }
            }
            // Mobile owner login: they chose "owner" on start page, treat as owner
            if (finalRole == null) {
              final cachedRole =
                  cacheHelper.getData(key: 'userRole') as String?;
              if (cachedRole == 'owner') {
                finalRole = 'owner';
                await cacheHelper.saveData(key: 'userRole', value: 'owner');
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

          // Set currentUser BEFORE navigation to ensure role is set
          // This prevents _handleAuthStateChange from running with null role
          currentUser.value = user;

          // Small delay to ensure state is set before navigation
          await Future.delayed(const Duration(milliseconds: 100));

          // Navigate after setting currentUser
          Get.offAllNamed(targetRoute);
          await cacheHelper.saveData(key: 'isLoggedIn', value: true);
          await cacheHelper.saveData(key: 'userUid', value: user?.uid ?? '');
          await cacheHelper.saveData(
            key: 'userEmail',
            value: user?.email ?? '',
          );
          await cacheHelper.saveData(key: 'userRole', value: finalRole);

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
          // Only treat as error if we got a failure (e.g. exception)
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
          // OAuth flow started - browser opened. Don't navigate; auth state listener
          // will handle success when user returns from browser with tokens.
          if (user == null) return;

          // Check if user document exists in Firestore FIRST
          // If it doesn't exist, the account was deleted (restaurant was deleted)
          final userDoc = await Supabase.instance.client
              .from('users')
              .select('*')
              .eq('id', user?.uid ?? '')
              .maybeSingle();

          // Fetch and save user role from Supabase BEFORE setting currentUser
          // This prevents _handleAuthStateChange from routing with wrong role
          if (userDoc != null) {
            final role = userDoc['role'] as String?;
            if (role != null && role.isNotEmpty) {
              await cacheHelper.saveData(key: 'userRole', value: role);
            }
          }

          // Sync restaurant info completion status from Supabase
          if (user?.uid != null) {
            await syncRestaurantInfoCompleted();
          }

          // Double-check role is set
          var finalRole = cacheHelper.getData(key: 'userRole') as String?;
          if (finalRole == null) {
            // Role still not set, fetch again
            final userDocCheck = await Supabase.instance.client
                .from('users')
                .select('*')
                .eq('id', user?.uid ?? '')
                .maybeSingle();
            if (userDocCheck != null) {
              finalRole = userDocCheck['role'] as String?;
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
          } else if (failure.statusCode == 503) {
            errorMessage.value = failure.errMessage;
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
            duration: const Duration(seconds: 6),
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

          // Get role from cache (set in start_page) or default to owner
          final role =
              cacheHelper.getData(key: 'userRole') as String? ?? 'owner';

          bool isNewUser = true;
          // Ensure a row exists in users (insert or update) - Supabase Auth does not create it
          try {
            final existing = await Supabase.instance.client
                .from('users')
                .select('id')
                .eq('id', user?.uid ?? '')
                .maybeSingle();
            isNewUser = existing == null;

            final userRow = {
              'id': user?.uid ?? '',
              'email': user?.email ?? '',
              'role': role,
              'updated_at': DateTime.now().toIso8601String(),
            };
            if (isNewUser) {
              userRow['created_at'] = DateTime.now().toIso8601String();
              await Supabase.instance.client.from('users').insert(userRow);
            } else {
              await Supabase.instance.client
                  .from('users')
                  .update(userRow)
                  .eq('id', user?.uid ?? '');
            }
          } catch (e) {
            print('[AuthController] signUp users table error: $e');
            // Try upsert as fallback (if table has onConflict)
            try {
              await Supabase.instance.client.from('users').upsert({
                'id': user?.uid ?? '',
                'email': user?.email ?? '',
                'role': role,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              }, onConflict: 'id');
            } catch (upsertErr) {
              print('[AuthController] signUp users upsert error: $upsertErr');
            }
          }

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

          // Supabase sends confirmation email automatically on signUp when enabled.
          // Only show verify screen if email confirmation is required (user not yet confirmed)
          final authUser = Supabase.instance.client.auth.currentUser;
          final isEmailConfirmed = authUser?.emailConfirmedAt != null;

          if (isEmailConfirmed) {
            // Email confirmation disabled in Supabase or user already confirmed
            final targetRoute = isNewUser
                ? AppPages.completeRestaurantInfo
                : await _ownerNextRoute();
            Get.offAllNamed(targetRoute);
            return;
          }

          // Show verify email screen (Supabase sent confirmation email on signUp)
          Get.offAllNamed(
            AppPages.verifyEmail,
            arguments: {
              'email': user?.email ?? '',
              'onResendVerification': () async {
                await sendEmailVerification();
              },
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
                  final currentUser = Supabase.instance.client.auth.currentUser;
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
              'onLogout': () async {
                await signOut();
                Get.offAllNamed(AppPages.root);
              },
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

    // If role is not set, try to fetch it from Supabase or use cache (mobile owner)
    if (userRole == null) {
      final uid = cacheHelper.getData(key: 'userUid') as String?;
      if (uid != null) {
        try {
          final userDoc = await Supabase.instance.client
              .from('users')
              .select('*')
              .eq('id', uid)
              .maybeSingle();

          if (userDoc != null) {
            userRole = userDoc['role'] as String?;
            print('🔍 [AuthController] Fetched role from Supabase: $userRole');
            if (userRole != null) {
              await cacheHelper.saveData(key: 'userRole', value: userRole);
            }
          }
        } catch (e) {
          print('Error fetching role in _ownerNextRoute: $e');
        }
      }
      // Mobile owner: they chose owner on start page, cache may have it
      if (userRole == null) {
        final cachedRole = cacheHelper.getData(key: 'userRole') as String?;
        if (cachedRole == 'owner') {
          userRole = 'owner';
          await cacheHelper.saveData(key: 'userRole', value: 'owner');
          print(
            '🔍 [AuthController] _ownerNextRoute using cached owner role (mobile)',
          );
        }
      }
    }

    // If admin, return dashboard
    if (userRole == 'admin') {
      print('🔍 [AuthController] User is admin, returning dashboard');
      return AppPages.dashboard;
    }

    final uid = cacheHelper.getData(key: 'userUid') as String?;
    final email = cacheHelper.getData(key: 'userEmail') as String?;

    // Not owner (e.g. customer or unknown in owner flow) → complete restaurant info
    if (userRole != 'owner') {
      // Still not owner (e.g. customer or unknown), go to complete info as safe fallback for owner flow
      print(
        '🔍 [AuthController] Role is not owner ($userRole), going to complete restaurant info',
      );
      await cacheHelper.saveData(key: 'restaurantInfoCompleted', value: false);
      return AppPages.completeRestaurantInfo;
    }

    print(
      '🔍 [AuthController] User is owner, checking restaurant info completion',
    );
    print('🔍 [AuthController] Owner UID: $uid, Email: $email');

    if (uid != null || (email != null && email.isNotEmpty)) {
      try {
        print(
          '🔍 [AuthController] Checking restaurant existence for ownerId: $uid, ownerEmail: $email',
        );

        // First, check if restaurant actually exists
        final restaurantInfo = await _restaurantService.getRestaurantByOwnerId(
          uid ?? '',
        );

        // If restaurant doesn't exist, reset restaurantInfoCompleted and go to complete info
        if (restaurantInfo == null) {
          print(
            '🔍 [AuthController] No restaurant found. Resetting restaurantInfoCompleted to false.',
          );
          await cacheHelper.saveData(
            key: 'restaurantInfoCompleted',
            value: false,
          );
          return AppPages.completeRestaurantInfo;
        }

        // Restaurant exists, check completion status
        print(
          '🔍 [AuthController] Restaurant found. Checking completion status...',
        );
        final isCompleted = await _restaurantService.getRestaurantInfoCompleted(
          ownerId: uid!,
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
        // On error, check if restaurant exists by trying to get it
        try {
          final restaurantInfo = await _restaurantService
              .getRestaurantByOwnerId(uid ?? '');
          if (restaurantInfo == null) {
            // No restaurant found, reset and go to complete info
            await cacheHelper.saveData(
              key: 'restaurantInfoCompleted',
              value: false,
            );
            return AppPages.completeRestaurantInfo;
          }
        } catch (e2) {
          print('🔍 [AuthController] Error checking restaurant existence: $e2');
        }
        // Fallback to cached value
        final isCompleted =
            await cacheHelper.getData(key: 'restaurantInfoCompleted')
                as bool? ??
            false;
        print('🔍 [AuthController] Using cached value: $isCompleted');
        return isCompleted ? AppPages.home : AppPages.completeRestaurantInfo;
      }
    }
    // No uid or email, reset and go to complete info
    await cacheHelper.saveData(key: 'restaurantInfoCompleted', value: false);
    return AppPages.completeRestaurantInfo;
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
