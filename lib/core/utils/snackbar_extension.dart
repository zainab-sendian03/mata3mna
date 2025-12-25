import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Extension on Get to add responsive snackbar method
extension ResponsiveSnackbar on GetInterface {
  /// Shows a responsive snackbar that doesn't take full width on desktop
  void responsiveSnackbar(
    String title,
    String message, {
    SnackPosition snackPosition = SnackPosition.BOTTOM,
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    Color? colorText,
    IconData? icon,
    bool shouldIconPulse = false,
  }) {
    final screenWidth = Get.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    
    // Calculate max width based on screen size
    final maxWidth = isDesktop ? 400.0 : (isTablet ? 350.0 : null);
    
    // Calculate margin to center the snackbar on desktop/tablet
    EdgeInsets margin;
    if (isDesktop || isTablet) {
      final horizontalMargin = maxWidth != null
          ? (screenWidth - maxWidth) / 2
          : 16.0;
      margin = EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: 16,
      );
    } else {
      margin = EdgeInsets.all(16);
    }

    Get.snackbar(
      title,
      message,
      snackPosition: snackPosition,
      duration: duration,
      backgroundColor: backgroundColor,
      colorText: colorText,
      icon: icon != null ? Icon(icon, color: colorText ?? Colors.white) : null,
      margin: margin,
      maxWidth: maxWidth,
      borderRadius: 12,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOutBack,
      shouldIconPulse: shouldIconPulse,
      snackStyle: SnackStyle.FLOATING,
    );
  }
}

