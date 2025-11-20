class AppConstants {
  // App Information
  static const String appName = 'Firebase Test';
  static const String appVersion = '1.0.0';

  // API Constants
  static const String baseUrl = 'https://api.example.com';
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // Validation Constants
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 50;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 100;
  static const int minEmailLength = 8;
  static const int maxEmailLength = 100;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultMargin = 16.0;
  static const double defaultBorderRadius = 12.0;
  static const double defaultElevation = 2.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userDataKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';

  // Error Messages
  static const String networkError = 'Network connection error';
  static const String serverError = 'Server error occurred';
  static const String unknownError = 'An unknown error occurred';
  static const String validationError = 'Please check your input';

  // Success Messages
  static const String loginSuccess = 'Login successful';
  static const String signupSuccess = 'Account created successfully';
  static const String logoutSuccess = 'Logged out successfully';
  static const String noteSaved = 'Note saved successfully';
  static const String noteDeleted = 'Note deleted successfully';
}
