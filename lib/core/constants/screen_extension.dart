import 'package:flutter/material.dart';

extension ScreenSize on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  double get screenAspectRatio => MediaQuery.of(this).size.aspectRatio;

  // Responsive breakpoints
  bool get isMobile => screenWidth < 768;
  bool get isTablet => screenWidth >= 768 && screenWidth < 1024;
  bool get isDesktop => screenWidth >= 1024;

  // Safe area dimensions
  double get safeAreaTop => MediaQuery.of(this).padding.top;
  double get safeAreaBottom => MediaQuery.of(this).padding.bottom;
  double get safeAreaLeft => MediaQuery.of(this).padding.left;
  double get safeAreaRight => MediaQuery.of(this).padding.right;

  // Responsive padding
  EdgeInsets get responsivePadding => EdgeInsets.symmetric(
        horizontal: isMobile
            ? 16.0
            : isTablet
                ? 24.0
                : 32.0,
        vertical: isMobile
            ? 8.0
            : isTablet
                ? 12.0
                : 16.0,
      );

  // Responsive font sizes
  double get responsiveFontSize => isMobile
      ? 14.0
      : isTablet
          ? 16.0
          : 18.0;
  double get responsiveTitleFontSize => isMobile
      ? 20.0
      : isTablet
          ? 24.0
          : 28.0;

  // Responsive spacing
  double get responsiveSpacing => isMobile
      ? 8.0
      : isTablet
          ? 12.0
          : 16.0;
  double get responsiveLargeSpacing => isMobile
      ? 16.0
      : isTablet
          ? 24.0
          : 32.0;
}
