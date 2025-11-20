import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/themes/assets.dart';
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
                    onPressed: () {
                      Get.toNamed(AppPages.home);
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
                    onPressed: () {
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
