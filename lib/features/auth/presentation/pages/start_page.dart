import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/themes/assets.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:sizer/sizer.dart';

class ChooseRolePage extends StatelessWidget {
  const ChooseRolePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              children: [
                /// الصورة الخلفية
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(Assets.assetsImagesFood),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                /// الغباش
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 3, // درجة الغباش أفقياً
                    sigmaY: 3, // درجة الغباش عمودياً
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(0.4), // للتعتيم الخفيف
                  ),
                ),
              ],
            ),
          ),

          /// ------- MAIN CONTENT -------
          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 9.h),

                Text(
                  "مرحباً بك في تطبيق مطاعمنا !",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 2.h),

                Text(
                  "اختر طريقة استخدام التطبيق",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),

                /// USER BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      print('[StartPage] Customer button pressed');
                      final cacheHelper = Get.find<CacheHelper>();
                      await cacheHelper.saveData(
                        key: 'userRole',
                        value: 'customer',
                      );
                      print('[StartPage] Saved userRole = customer');

                      // Don't set isLoggedIn=true for customers - they don't need Firebase auth
                      // await cacheHelper.saveData(
                      //   key: 'isLoggedIn',
                      //   value: true,
                      // );

                      // Try to save to Firestore, but don't block if it fails
                      try {
                        final userUid =
                            cacheHelper.getData(key: 'userUid') as String?;
                        if (userUid != null && userUid.isNotEmpty) {
                          print(
                            '[StartPage] Saving to Firestore with UID: $userUid',
                          );
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(userUid)
                              .set({
                                'role': 'customer',
                                'email': cacheHelper.getData(key: 'userEmail'),
                                'displayName': cacheHelper.getData(
                                  key: 'userDisplayName',
                                ),
                                'createdAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                          print('[StartPage] Successfully saved to Firestore');
                        } else {
                          print(
                            '[StartPage] No userUid found, skipping Firestore save',
                          );
                        }
                      } catch (e) {
                        // Ignore Firestore errors for customers - they can still browse
                        print(
                          '[StartPage] Failed to save customer role to Firestore: $e',
                        );
                      }

                      print(
                        '[StartPage] Navigating to ${AppPages.customerView}',
                      );
                      Get.offAllNamed(AppPages.customerView);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "المتابعة كـ مستخدم",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                /// OWNER BUTTON
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final cacheHelper = Get.find<CacheHelper>();
                      final userUid =
                          cacheHelper.getData(key: 'userUid') as String?;

                      // Save role to cache
                      await cacheHelper.saveData(
                        key: 'userRole',
                        value: 'owner',
                      );

                      // Save role to Firestore if user is already logged in
                      if (userUid != null && userUid.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userUid)
                            .set({
                              'role': 'owner',
                              'email': cacheHelper.getData(key: 'userEmail'),
                              'displayName': cacheHelper.getData(
                                key: 'userDisplayName',
                              ),
                              'createdAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                      }

                      Get.toNamed(AppPages.login);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "أنا صاحب مطعم",
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 2.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
