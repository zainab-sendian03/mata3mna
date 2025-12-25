import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';

/// Middleware to prevent admins from accessing owner-only routes
class OwnerOnlyMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final cacheHelper = Get.find<CacheHelper>();
    final userRole = cacheHelper.getData(key: 'userRole') as String?;

    // If user is admin, redirect to dashboard
    if (userRole == 'admin') {
      return const RouteSettings(name: AppPages.dashboard);
    }

    // Allow access for owners and other roles
    return null;
  }
}

/// Middleware to redirect admins from root page to admin login
class AdminRedirectMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final cacheHelper = Get.find<CacheHelper>();
    final userRole = cacheHelper.getData(key: 'userRole') as String?;

    // If user is admin, redirect to admin login page
    if (userRole == 'admin') {
      return const RouteSettings(name: AppPages.adminLogin);
    }

    // Allow access for other roles
    return null;
  }
}
