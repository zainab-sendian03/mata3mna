import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for admin CRUD operations on restaurants, items, and categories
class AdminFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Store admin password in memory for session restoration
  // This is only stored temporarily while admin is logged in
  static String? _storedAdminPassword;

  /// Store admin password when admin logs in
  /// This allows us to restore admin session after creating owner accounts
  static void storeAdminPassword(String password) {
    _storedAdminPassword = password;
    print(
      '[AdminFirestoreService] ✅ Admin password stored in memory (length: ${password.length})',
    );
  }

  /// Get stored admin password
  static String? getStoredAdminPassword() {
    final password = _storedAdminPassword;
    print(
      '[AdminFirestoreService] getStoredAdminPassword called. Password exists: ${password != null}',
    );
    return password;
  }

  /// Clear stored admin password (call on logout)
  static void clearStoredAdminPassword() {
    _storedAdminPassword = null;
    print('[AdminFirestoreService] Admin password cleared from memory');
  }

  // Collection names
  static const String _restaurantsCollection = 'restaurants';
  static const String _menuItemsCollection = 'menuItems';
  static const String _usersCollection = 'users';

  // ==================== RESTAURANTS ====================

  /// Get all restaurants (admin view - no filters)
  Stream<List<Map<String, dynamic>>> getAllRestaurants() {
    // Check if admin is authenticated
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print(
        '[AdminFirestoreService] WARNING: No authenticated user when trying to get restaurants',
      );
      // Return empty stream - the error will be handled by the controller
      return Stream.value([]);
    }

    print(
      '[AdminFirestoreService] Getting all restaurants. Current user: ${currentUser.email}',
    );

    return _firestore
        .collection(_restaurantsCollection)
        .snapshots()
        .map((snapshot) {
          final restaurants = snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();

          // Sort by updatedAt if available, otherwise by createdAt
          restaurants.sort((a, b) {
            final aUpdated = a['updatedAt'] as Timestamp?;
            final bUpdated = b['updatedAt'] as Timestamp?;
            if (aUpdated != null && bUpdated != null) {
              return bUpdated.compareTo(aUpdated); // Descending
            }
            final aCreated = a['createdAt'] as Timestamp?;
            final bCreated = b['createdAt'] as Timestamp?;
            if (aCreated != null && bCreated != null) {
              return bCreated.compareTo(aCreated); // Descending
            }
            return 0;
          });

          print(
            '[AdminFirestoreService] Loaded ${restaurants.length} restaurants',
          );
          return restaurants;
        })
        .handleError((error) {
          print(
            '[AdminFirestoreService] Error in getAllRestaurants stream: $error',
          );
          // Re-throw to be handled by the controller
          throw error;
        });
  }

  /// Get a single restaurant by ID
  Future<Map<String, dynamic>?> getRestaurantById(String restaurantId) async {
    try {
      final doc = await _firestore
          .collection(_restaurantsCollection)
          .doc(restaurantId)
          .get();

      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get restaurant: $e');
    }
  }

  /// Check if owner already has a restaurant
  Future<bool> ownerHasRestaurant(String ownerId, String ownerEmail) async {
    try {
      // Check by ownerId
      final byIdQuery = await _firestore
          .collection(_restaurantsCollection)
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (byIdQuery.docs.isNotEmpty) {
        return true;
      }

      // Check by email
      final byEmailQuery = await _firestore
          .collection(_restaurantsCollection)
          .where('ownerEmail', isEqualTo: ownerEmail)
          .limit(1)
          .get();

      return byEmailQuery.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check restaurant existence: $e');
    }
  }

  /// Check if Firebase Auth user exists by email
  /// Note: We can't directly check if a user exists without trying to create one
  /// This method will be handled in createOrGetUserByEmail

  /// Create or get user by email with password
  /// Creates both Firebase Auth user and Firestore document
  /// Preserves the current admin session by restoring it after creating the owner
  Future<Map<String, dynamic>> createOrGetUserByEmail(
    String email,
    String password, {
    String? adminEmail,
    String? adminPassword,
  }) async {
    try {
      // Validate inputs
      if (email.isEmpty || !email.contains('@')) {
        throw Exception('البريد الإلكتروني غير صحيح');
      }
      if (password.isEmpty || password.length < 6) {
        throw Exception('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      }

      // Trim and validate password
      final trimmedPassword = password.trim();
      if (trimmedPassword.isEmpty || trimmedPassword.length < 6) {
        throw Exception(
          'كلمة المرور يجب أن تكون 6 أحرف على الأقل (بعد إزالة المسافات)',
        );
      }

      // Use trimmed password
      final finalPassword = trimmedPassword;

      print('[AdminFirestoreService] Creating/getting user with email: $email');
      print(
        '[AdminFirestoreService] Password length: ${finalPassword.length} characters',
      );
      print(
        '[AdminFirestoreService] Password contains whitespace: ${finalPassword != password}',
      );

      // Store current admin session info BEFORE creating new user
      // Firebase Auth automatically signs in the new user, which signs out the admin
      final currentAdmin = _auth.currentUser;
      final adminEmailToRestore = adminEmail ?? currentAdmin?.email;
      // Try to get admin password from parameter, or from stored password
      final storedPassword = getStoredAdminPassword();
      final adminPasswordToRestore = adminPassword ?? storedPassword;
      final wasAdminLoggedIn =
          currentAdmin != null && currentAdmin.email != null;

      print(
        '[AdminFirestoreService] Current admin before creating owner: ${currentAdmin?.email}',
      );
      print('[AdminFirestoreService] Admin was logged in: $wasAdminLoggedIn');
      print(
        '[AdminFirestoreService] Stored password exists: ${storedPassword != null}',
      );
      print(
        '[AdminFirestoreService] Admin email to restore: $adminEmailToRestore',
      );
      print(
        '[AdminFirestoreService] Admin password provided: ${adminPassword != null}',
      );
      print(
        '[AdminFirestoreService] Admin password from storage: ${storedPassword != null}',
      );
      print(
        '[AdminFirestoreService] Will restore admin session: ${adminEmailToRestore != null && adminPasswordToRestore != null}',
      );

      // If admin is logged in but password is not stored, we need it to restore session
      // This happens when admin auto-logged in (remember me) without going through signInWithEmail
      if (wasAdminLoggedIn &&
          adminPasswordToRestore == null &&
          adminEmailToRestore != null) {
        throw Exception(
          'كلمة مرور المسؤول مطلوبة لاستعادة الجلسة. يرجى تسجيل الخروج وتسجيل الدخول مرة أخرى، أو إعادة تشغيل التطبيق.',
        );
      }

      // First, try to create Firebase Auth account (this ensures Auth account exists)
      // If it already exists, we'll catch that and fetch the existing user
      User? firebaseUser;
      bool authAccountExists = false;
      bool isNewUser = false;

      try {
        print(
          '[AdminFirestoreService] Creating Firebase Auth account for: $email',
        );
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: finalPassword,
        );
        firebaseUser = userCredential.user;
        isNewUser = true;

        if (firebaseUser == null || firebaseUser.uid.isEmpty) {
          throw Exception(
            'فشل في إنشاء حساب المصادقة: لم يتم الحصول على معرف المستخدم',
          );
        }

        print(
          '[AdminFirestoreService] Firebase Auth account created successfully. UID: ${firebaseUser.uid}, Email: ${firebaseUser.email}',
        );

        // NOTE: createUserWithEmailAndPassword automatically signs in the new user
        // Wait a moment to ensure the account is fully committed to Firebase Auth
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify the current user is the newly created one
        final currentSignedInUser = _auth.currentUser;
        if (currentSignedInUser?.uid != firebaseUser.uid) {
          print(
            '[AdminFirestoreService] WARNING: Current user mismatch. Expected: ${firebaseUser.uid}, Got: ${currentSignedInUser?.uid}',
          );
        } else {
          print(
            '[AdminFirestoreService] Verified: New owner is currently signed in',
          );
        }

        // IMPORTANT: Create Firestore user document while the new owner is still signed in
        // This ensures the Firestore security rules allow the write operation
        // The new owner can write their own document
        print(
          '[AdminFirestoreService] Creating Firestore user document while owner is signed in...',
        );
        final userData = {
          'email': email.trim(),
          'role': 'owner',
          'displayName': email.trim().split('@')[0],
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        try {
          await _firestore
              .collection(_usersCollection)
              .doc(firebaseUser.uid)
              .set(userData, SetOptions(merge: true));
          print(
            '[AdminFirestoreService] ✅ Firestore user document created successfully',
          );
        } catch (firestoreError) {
          print(
            '[AdminFirestoreService] ⚠️ WARNING: Could not create Firestore user document: $firestoreError',
          );
          print(
            '[AdminFirestoreService] This might be due to Firestore security rules.',
          );
          print(
            '[AdminFirestoreService] The document will be created when the owner first logs in.',
          );
          // Don't throw - the Auth account was created successfully
          // The Firestore document can be created when the owner first logs in
          // This is handled in the auth_controller when they sign in
        }

        // IMPORTANT: Sign out the new owner immediately to restore admin session
        print(
          '[AdminFirestoreService] Signing out new owner to restore admin session...',
        );
        await _auth.signOut();
        await Future.delayed(const Duration(milliseconds: 300));

        // Restore admin session if credentials were provided
        if (adminEmailToRestore != null && adminPasswordToRestore != null) {
          try {
            print(
              '[AdminFirestoreService] Restoring admin session for: $adminEmailToRestore',
            );
            await _auth.signInWithEmailAndPassword(
              email: adminEmailToRestore,
              password: adminPasswordToRestore,
            );

            final restoredAdmin = _auth.currentUser;
            if (restoredAdmin?.email == adminEmailToRestore) {
              print(
                '[AdminFirestoreService] ✅ Admin session restored successfully!',
              );
            } else {
              print(
                '[AdminFirestoreService] ⚠️ WARNING: Admin session restoration may have failed',
              );
            }
          } catch (restoreError) {
            print(
              '[AdminFirestoreService] ❌ ERROR: Failed to restore admin session: $restoreError',
            );
            print(
              '[AdminFirestoreService] Admin will need to sign in again manually.',
            );
            // Don't throw - the owner account was created successfully
            // Admin can sign in again manually
          }
        } else {
          print(
            '[AdminFirestoreService] ❌ No admin credentials provided. Admin will need to sign in again.',
          );
          print(
            '[AdminFirestoreService] Admin email: $adminEmailToRestore, Password: ${adminPasswordToRestore != null ? "provided" : "missing"}',
          );
          print(
            '[AdminFirestoreService] Stored password check: ${getStoredAdminPassword() != null ? "exists" : "not found"}',
          );

          // Try one more time to get the password - maybe it was just stored
          final retryPassword = getStoredAdminPassword();
          if (retryPassword != null && adminEmailToRestore != null) {
            print(
              '[AdminFirestoreService] Retrying admin session restoration with stored password...',
            );
            try {
              await _auth.signInWithEmailAndPassword(
                email: adminEmailToRestore,
                password: retryPassword,
              );
              final restoredAdmin = _auth.currentUser;
              if (restoredAdmin?.email == adminEmailToRestore) {
                print(
                  '[AdminFirestoreService] ✅ Admin session restored successfully on retry!',
                );
              }
            } catch (retryError) {
              print('[AdminFirestoreService] ❌ Retry failed: $retryError');
            }
          }
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Firebase Auth account already exists - this is an existing user
          authAccountExists = true;
          print(
            '[AdminFirestoreService] Email already exists in Firebase Auth. This is an existing user.',
          );

          // For existing users, we don't need to create/update their Firestore document
          // We just need to get their UID from Firestore
          // Try to find the user in Firestore by email
          try {
            final emailQuery = await _firestore
                .collection(_usersCollection)
                .where('email', isEqualTo: email.trim())
                .limit(1)
                .get();

            if (emailQuery.docs.isNotEmpty) {
              final doc = emailQuery.docs.first;
              final data = doc.data();
              final existingUid = doc.id;

              print(
                '[AdminFirestoreService] Found existing user in Firestore. UID: $existingUid',
              );

              // Return the existing user data without trying to update
              return {
                'id': existingUid,
                'uid': existingUid,
                'email': data['email'] ?? email.trim(),
                'displayName':
                    data['displayName'] ?? email.trim().split('@')[0],
                'role': data['role'] ?? 'owner',
                ...data,
              };
            } else {
              // User exists in Auth but not in Firestore - this shouldn't happen normally
              // But we can't create the document without signing in as them
              print(
                '[AdminFirestoreService] WARNING: User exists in Auth but not in Firestore',
              );
              print(
                '[AdminFirestoreService] The Firestore document will be created when the owner logs in.',
              );

              // We can't get the UID without signing in, so we need to try that
              // But we'll skip the Firestore update
              try {
                final signInResult = await _auth.signInWithEmailAndPassword(
                  email: email.trim(),
                  password: finalPassword,
                );
                firebaseUser = signInResult.user;
                await _auth.signOut();
                print(
                  '[AdminFirestoreService] Got UID from sign-in: ${firebaseUser?.uid}',
                );
              } catch (signInError) {
                print(
                  '[AdminFirestoreService] Could not sign in to get UID: $signInError',
                );
                throw Exception(
                  'البريد الإلكتروني مستخدم بالفعل ولكن لا يمكن الوصول إلى الحساب. '
                  'يرجى التحقق من كلمة المرور أو استخدام بريد إلكتروني آخر.',
                );
              }
            }
          } catch (firestoreError) {
            print(
              '[AdminFirestoreService] Error querying Firestore for existing user: $firestoreError',
            );
            // Fall through to try sign-in approach
            try {
              final signInResult = await _auth.signInWithEmailAndPassword(
                email: email.trim(),
                password: finalPassword,
              );
              firebaseUser = signInResult.user;
              await _auth.signOut();
            } catch (signInError) {
              authAccountExists = true;
            }
          }
        } else if (e.code == 'weak-password') {
          throw Exception(
            'كلمة المرور ضعيفة. يرجى استخدام كلمة مرور أقوى (6 أحرف على الأقل)',
          );
        } else if (e.code == 'invalid-email') {
          throw Exception('البريد الإلكتروني غير صحيح');
        } else if (e.code == 'operation-not-allowed') {
          throw Exception(
            'طريقة تسجيل الدخول غير مفعلة. يرجى تفعيل Email/Password في Firebase Console > Authentication > Sign-in method',
          );
        } else if (e.message?.contains('403') == true ||
            e.message?.contains('Forbidden') == true ||
            e.message?.contains('permission') == true) {
          throw Exception(
            'خطأ في الصلاحيات (403). يرجى:\n'
            '1. تفعيل Identity Toolkit API في Google Cloud Console\n'
            '2. تفعيل Email/Password في Firebase Console\n'
            '3. التحقق من قيود API Key',
          );
        } else {
          throw Exception('فشل إنشاء حساب المصادقة: ${e.message ?? e.code}');
        }
      } catch (e) {
        // Catch any other errors (like network errors that might show 403)
        final errorStr = e.toString();
        if (errorStr.contains('403') ||
            errorStr.contains('Forbidden') ||
            errorStr.contains('permission')) {
          throw Exception(
            'خطأ في الصلاحيات (403). يرجى:\n'
            '1. تفعيل Identity Toolkit API في Google Cloud Console\n'
            '2. تفعيل Email/Password في Firebase Console\n'
            '3. التحقق من قيود API Key',
          );
        }
        rethrow;
      }

      // Get the UID from Firebase Auth user
      String uid = firebaseUser?.uid ?? '';

      // Verify the user was created successfully
      if (isNewUser && uid.isEmpty) {
        print(
          '[AdminFirestoreService] ERROR: New user created but UID is empty!',
        );
        throw Exception(
          'فشل في إنشاء حساب المصادقة: لم يتم الحصول على معرف المستخدم',
        );
      }

      if (isNewUser) {
        print(
          '[AdminFirestoreService] Successfully created new owner with UID: $uid, Email: $email',
        );
      }

      // If we don't have a UID yet (account exists but password might be wrong),
      // try to find user in Firestore by email
      if (uid.isEmpty && authAccountExists) {
        final emailQuery = await _firestore
            .collection(_usersCollection)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (emailQuery.docs.isNotEmpty) {
          final doc = emailQuery.docs.first;
          uid = doc.id; // Use Firestore document ID as UID
          final data = doc.data();
          return {
            'id': uid,
            'uid': uid,
            'email': data['email'] ?? email,
            'displayName': data['displayName'] ?? email.split('@')[0],
            ...data,
          };
        } else {
          throw Exception(
            'البريد الإلكتروني مستخدم بالفعل في نظام المصادقة ولكن لا يوجد سجل في قاعدة البيانات. يرجى استخدام بريد آخر أو إعادة تعيين كلمة المرور',
          );
        }
      }

      if (uid.isEmpty) {
        throw Exception('فشل الحصول على معرف المستخدم');
      }

      // Create or update Firestore document (if not already created above)
      // For new users, the document should already be created while they were signed in
      // For existing users, we skip the update to avoid permission errors
      // The document already exists and doesn't need to be updated by admin
      if (!isNewUser) {
        print(
          '[AdminFirestoreService] Existing user - skipping Firestore document update',
        );
        print(
          '[AdminFirestoreService] Using existing user data from Firestore',
        );

        // Just verify the document exists, but don't try to update it
        try {
          final existingUserDoc = await _firestore
              .collection(_usersCollection)
              .doc(uid)
              .get();

          if (existingUserDoc.exists) {
            print(
              '[AdminFirestoreService] ✅ Existing user document found in Firestore',
            );
            // Use the existing data
            final existingData = existingUserDoc.data();
            return {
              'id': uid,
              'uid': uid,
              'email': existingData?['email'] ?? email.trim(),
              'displayName':
                  existingData?['displayName'] ?? email.trim().split('@')[0],
              'role': existingData?['role'] ?? 'owner',
              ...?existingData,
            };
          } else {
            print(
              '[AdminFirestoreService] ⚠️ WARNING: User exists in Auth but not in Firestore',
            );
            print(
              '[AdminFirestoreService] Document will be created when owner logs in',
            );
            // Return basic data - document will be created on first login
            return {
              'id': uid,
              'uid': uid,
              'email': email.trim(),
              'displayName': email.trim().split('@')[0],
              'role': 'owner',
            };
          }
        } catch (firestoreError) {
          print(
            '[AdminFirestoreService] ⚠️ Could not verify Firestore document: $firestoreError',
          );
          print(
            '[AdminFirestoreService] Returning basic user data - document will be created on login',
          );
          // Return basic data without Firestore document
          return {
            'id': uid,
            'uid': uid,
            'email': email.trim(),
            'displayName': email.trim().split('@')[0],
            'role': 'owner',
          };
        }
      } else {
        print(
          '[AdminFirestoreService] Firestore user document should already exist for new user',
        );
        // Verify the document exists
        try {
          final verifyDoc = await _firestore
              .collection(_usersCollection)
              .doc(uid)
              .get();
          if (!verifyDoc.exists) {
            print(
              '[AdminFirestoreService] WARNING: Firestore user document was not created. Attempting to create now...',
            );
            // Try to create it now (might fail due to permissions, but worth trying)
            final createUserData = {
              'email': email.trim(),
              'role': 'owner',
              'displayName': email.trim().split('@')[0],
              'updatedAt': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
            };
            await _firestore
                .collection(_usersCollection)
                .doc(uid)
                .set(createUserData, SetOptions(merge: true));
            print('[AdminFirestoreService] Created Firestore user document');
          }
        } catch (verifyError) {
          print(
            '[AdminFirestoreService] Could not verify/create Firestore user document: $verifyError',
          );
          // Don't throw - the Auth account was created successfully
          // The Firestore document can be created when the owner first logs in
        }
      }

      // Verify the user was created successfully (only if we tried to create it)
      // If creation failed due to permissions, the document will be created on first login
      if (isNewUser) {
        final verifiedUserDoc = await _firestore
            .collection(_usersCollection)
            .doc(uid)
            .get();

        if (!verifiedUserDoc.exists) {
          print(
            '[AdminFirestoreService] WARNING: Firestore user document was not created!',
          );
          print(
            '[AdminFirestoreService] This might be due to Firestore security rules.',
          );
          print(
            '[AdminFirestoreService] The document will be created automatically when the owner first logs in.',
          );
          // Don't throw - the Auth account was created successfully
          // The Firestore document will be created when the owner logs in (handled in auth_controller)
        } else {
          print(
            '[AdminFirestoreService] ✅ Verified Firestore user document exists',
          );
        }
      }

      print(
        '[AdminFirestoreService] Successfully created owner account. UID: $uid, Email: $email, Role: owner',
      );

      // Get the final user data from Firestore
      final finalUserDoc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();

      final finalUserData = finalUserDoc.exists
          ? finalUserDoc.data()
          : <String, dynamic>{
              'email': email.trim(),
              'role': 'owner',
              'displayName': email.trim().split('@')[0],
            };

      return {
        'id': uid,
        'uid': uid,
        'email': email.trim(),
        'displayName': email.trim().split('@')[0],
        'role': 'owner',
        ...?finalUserData,
      };
    } catch (e) {
      print('[AdminFirestoreService] ERROR in createOrGetUserByEmail: $e');
      if (e.toString().contains('البريد الإلكتروني') ||
          e.toString().contains('كلمة المرور') ||
          e.toString().contains('غير صحيح')) {
        rethrow;
      }
      throw Exception('فشل في إنشاء/الحصول على المستخدم: $e');
    }
  }

  /// Create a new restaurant
  Future<String> createRestaurant({
    required String ownerId,
    required String ownerEmail,
    required String name,
    required String phone,
    required String governorate,
    required String city,
    String? description,
    String? logoPath,
    String? status,
  }) async {
    try {
      // Check if owner already has a restaurant
      final hasRestaurant = await ownerHasRestaurant(ownerId, ownerEmail);
      if (hasRestaurant) {
        throw Exception(
          'المالك لديه مطعم بالفعل. كل بريد إلكتروني يمكن أن يكون له مطعم واحد فقط.',
        );
      }

      final payload = <String, dynamic>{
        'ownerId': ownerId,
        'ownerEmail': ownerEmail,
        'name': name,
        'phone': phone,
        'governorate': governorate,
        'city': city,
        'description': description ?? '',
        'logoPath': logoPath ?? '',
        'status': status ?? 'active',
        'infoCompleted': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('Creating restaurant with payload: $payload');
      print('Collection: $_restaurantsCollection');
      print('OwnerId: $ownerId, OwnerEmail: $ownerEmail');

      final docRef = await _firestore
          .collection(_restaurantsCollection)
          .add(payload);

      print('Restaurant created successfully with ID: ${docRef.id}');

      // Wait a bit for Firestore to process
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify the document was created
      final createdDoc = await docRef.get();
      if (!createdDoc.exists) {
        print('ERROR: Restaurant document was not found after creation!');
        throw Exception('Restaurant document was not created in Firestore');
      }

      final docData = createdDoc.data();
      print('Verified restaurant document exists in Firestore');
      print('Document data: $docData');
      print('Document path: ${createdDoc.reference.path}');

      return docRef.id;
    } catch (e) {
      print('ERROR creating restaurant: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      if (e.toString().contains('المالك لديه مطعم بالفعل')) {
        rethrow;
      }
      throw Exception('Failed to create restaurant: $e');
    }
  }

  /// Update an existing restaurant
  Future<void> updateRestaurant({
    required String restaurantId,
    String? name,
    String? phone,
    String? governorate,
    String? city,
    String? description,
    String? logoPath,
    String? status,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;
      if (governorate != null) updateData['governorate'] = governorate;
      if (city != null) updateData['city'] = city;
      if (description != null) updateData['description'] = description;
      if (logoPath != null) updateData['logoPath'] = logoPath;
      if (status != null) updateData['status'] = status;

      await _firestore
          .collection(_restaurantsCollection)
          .doc(restaurantId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update restaurant: $e');
    }
  }

  /// Delete a restaurant
  Future<void> deleteRestaurant(String restaurantId) async {
    try {
      await _firestore
          .collection(_restaurantsCollection)
          .doc(restaurantId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete restaurant: $e');
    }
  }

  // ==================== MENU ITEMS ====================

  /// Get all menu items (admin view - from all restaurants)
  Stream<List<Map<String, dynamic>>> getAllMenuItems() {
    return _firestore
        .collection(_menuItemsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final item = <String, dynamic>{'id': doc.id, ...data};

            // Handle Timestamp fields
            if (item['createdAt'] != null && item['createdAt'] is Timestamp) {
              item['createdAt'] = (item['createdAt'] as Timestamp)
                  .toDate()
                  .toString();
            }
            if (item['updatedAt'] != null && item['updatedAt'] is Timestamp) {
              item['updatedAt'] = (item['updatedAt'] as Timestamp)
                  .toDate()
                  .toString();
            }

            return item;
          }).toList();
        });
  }

  /// Get a single menu item by ID
  Future<Map<String, dynamic>?> getMenuItemById(String itemId) async {
    try {
      final doc = await _firestore
          .collection(_menuItemsCollection)
          .doc(itemId)
          .get();

      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get menu item: $e');
    }
  }

  /// Create a new menu item
  Future<String> createMenuItem({
    required String name,
    required String category,
    required String price,
    required String ownerId,
    String? description,
    String? imageUrl,
    String? restaurantName,
  }) async {
    try {
      final menuItemData = {
        'name': name,
        'category': category,
        'price': price,
        'description': description ?? '',
        'image': imageUrl ?? '',
        'restaurantName': restaurantName ?? '',
        'ownerId': ownerId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection(_menuItemsCollection)
          .add(menuItemData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create menu item: $e');
    }
  }

  /// Update an existing menu item
  Future<void> updateMenuItem({
    required String itemId,
    String? name,
    String? category,
    String? price,
    String? description,
    String? imageUrl,
    String? restaurantName,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (category != null) updateData['category'] = category;
      if (price != null) updateData['price'] = price;
      if (description != null) updateData['description'] = description;
      if (imageUrl != null) updateData['image'] = imageUrl;
      if (restaurantName != null) updateData['restaurantName'] = restaurantName;

      await _firestore
          .collection(_menuItemsCollection)
          .doc(itemId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update menu item: $e');
    }
  }

  /// Delete a menu item
  Future<void> deleteMenuItem(String itemId) async {
    try {
      await _firestore.collection(_menuItemsCollection).doc(itemId).delete();
    } catch (e) {
      throw Exception('Failed to delete menu item: $e');
    }
  }

  // ==================== CATEGORIES ====================

  /// Get all unique categories from menu items
  Future<List<String>> getAllCategories() async {
    try {
      final snapshot = await _firestore.collection(_menuItemsCollection).get();

      final categories = <String>{};
      for (final doc in snapshot.docs) {
        final category = doc.data()['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }

      return categories.toList()..sort();
    } catch (e) {
      throw Exception('Failed to get categories: $e');
    }
  }

  /// Update category name in all menu items
  Future<void> updateCategoryName({
    required String oldCategory,
    required String newCategory,
  }) async {
    try {
      // Get all items with the old category
      final snapshot = await _firestore
          .collection(_menuItemsCollection)
          .where('category', isEqualTo: oldCategory)
          .get();

      // Update all items in batch
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'category': newCategory,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  /// Delete a category (moves items to "غير مصنف")
  Future<void> deleteCategory(String category) async {
    try {
      // Get all items with this category
      final snapshot = await _firestore
          .collection(_menuItemsCollection)
          .where('category', isEqualTo: category)
          .get();

      // Update all items to "غير مصنف" category
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'category': 'غير مصنف',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  /// Create a new category (just returns success, categories are created when items use them)
  Future<void> createCategory(String categoryName) async {
    // Categories are automatically created when menu items use them
    // This method exists for consistency but doesn't need to do anything
    return;
  }

  // ==================== USERS/OWNERS ====================

  /// Get all owners (users with role 'owner')
  Future<List<Map<String, dynamic>>> getAllOwners() async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: 'owner')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'uid': doc.id,
          'email': data['email'] ?? '',
          'displayName': data['displayName'] ?? '',
          ...data,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get owners: $e');
    }
  }

  /// Get owner by email
  Future<Map<String, dynamic>?> getOwnerByEmail(String email) async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'owner')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        return {
          'id': doc.id,
          'uid': doc.id,
          'email': data['email'] ?? '',
          'displayName': data['displayName'] ?? '',
          ...data,
        };
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get owner by email: $e');
    }
  }
}
