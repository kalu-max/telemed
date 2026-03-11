/// App Constants
/// Centralized constants used throughout the application
library;

class AppStrings {
  // App
  static const String appName = 'Telemedicine';
  static const String appTagline = 'Healthcare at Your Fingertips';

  // Authentication
  static const String login = 'Login';
  static const String register = 'Register';
  static const String logout = 'Logout';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String noAccount = "Don't have an account?";
  static const String haveAccount = 'Already have an account?';

  // Common
  static const String submit = 'Submit';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';

  // Call
  static const String initiateCall = 'Start Call';
  static const String endCall = 'End Call';
  static const String answerCall = 'Answer';
  static const String rejectCall = 'Reject';
  static const String callEnded = 'Call Ended';
  static const String callRejected = 'Call Rejected';

  // Navigation
  static const String home = 'Home';
  static const String dashboard = 'Dashboard';
  static const String appointments = 'Appointments';
  static const String profile = 'Profile';
  static const String settings = 'Settings';

  // Error Messages
  static const String emailRequired = 'Email is required';
  static const String passwordRequired = 'Password is required';
  static const String invalidEmail = 'Invalid email address';
  static const String passwordTooShort = 'Password must be at least 6 characters';
  static const String networkError = 'Network error. Please try again.';
  static const String serverError = 'Server error. Please try again later.';
  static const String unknownError = 'An unknown error occurred.';
}

class AppDurations {
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration snackbarDuration = Duration(seconds: 2);
  static const Duration dialogAnimationDuration = Duration(milliseconds: 300);
  static const Duration networkCheckInterval = Duration(seconds: 5);
  static const Duration metricsUpdateInterval = Duration(seconds: 1);
}

class AppSizes {
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 16.0;

  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
}

class AppDefaults {
  static const String locale = 'en_US';
  static const bool isDarkMode = false;
}
