import 'dart:ui';

class AppColors {
  // Base color: RGB(235, 142, 2) - Orange
  static const Color baseColor = Color(0xFFF57340);

  // Legacy/alias
  static const Color backgroundColor = Color.fromARGB(255, 255, 255, 255);
  static const Color appColor2 = baseColor;

  // Primary & secondary colors - derived from baseColor
  static const Color primaryLight = baseColor; // RGB(235, 142, 2) = #EB8E02
  static const Color primaryVariantLight = Color.fromARGB(
    255,
    200,
    120,
    2,
  ); // Darker orange
  static const Color primaryVariantLight2 = Color.fromARGB(
    255,
    255,
    180,
    50,
  ); // Lighter orange

  // Secondary colors - complementary to orange (blue tones)
  static const Color secondaryLight = Color.fromARGB(
    255,
    255,
    94,
    77,
  ); // Coral red
  static const Color secondaryVariantLight = Color.fromARGB(
    255,
    220,
    70,
    60,
  ); // Darker blue

  // Backgrounds & surfaces
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color dialogLight = Color(0xFFFFFFFF);

  // Feedback - warning uses orange theme
  static const Color errorLight = Color(0xFFDC2626);
  static const Color successLight = Color(0xFF10B981);
  static const Color warningLight = Color.fromARGB(
    255,
    255,
    165,
    0,
  ); // Orange-based warning

  // Text
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textDisabledLight = Color(0xFF94A3B8);

  // Border & divider
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFE2E8F0);

  // On-colors
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  static const Color onBackgroundLight = Color(0xFF0F172A);
  static const Color onSurfaceLight = Color(0xFF0F172A);
  static const Color onErrorLight = Color(0xFFFFFFFF);

  // Shadows
  static const Color shadowLight = Color(0x0A000000);

  // DARK MODE colors - orange-based theme
  static const Color primaryDark = Color.fromARGB(
    255,
    255,
    165,
    0,
  ); // Brighter orange for dark mode
  static const Color primaryVariantDark = Color.fromARGB(
    255,
    235,
    142,
    2,
  ); // Base orange
  static const Color primaryVariantDark2 = Color.fromARGB(
    255,
    200,
    120,
    2,
  ); // Darker orange

  // Secondary colors for dark mode
  static const Color secondaryDark = Color.fromARGB(
    255,
    255,
    130,
    100,
  ); // Lighter coral for darkasaS
  static const Color secondaryVariantDark = Color.fromARGB(
    255,
    255,
    94,
    77,
  ); // Base blue

  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF334155);
  static const Color dialogDark = Color(0xFF334155);

  static const Color errorDark = Color(0xFFF87171);
  static const Color successDark = Color(0xFF34D399);
  static const Color warningDark = Color.fromARGB(
    255,
    255,
    200,
    50,
  ); // Orange-based warning for dark

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textDisabledDark = Color(0xFF64748B);

  static const Color borderDark = Color(0xFF475569);
  static const Color dividerDark = Color(0xFF475569);

  static const Color onPrimaryDark = Color(0xFFFFFFFF);
  static const Color onSecondaryDark = Color(0xFFFFFFFF);
  static const Color onBackgroundDark = Color(0xFFF8FAFC);
  static const Color onSurfaceDark = Color(0xFFF8FAFC);
  static const Color onErrorDark = Color(0xFFFFFFFF);

  static const Color shadowDark = Color(0x1A000000);
  static const Color facebookColor = Color(0xFF4466C9);
  static const Color googleColor = Color(0xFFD02E2A);
}
