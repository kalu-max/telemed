import 'dart:async';
import 'package:flutter/foundation.dart';

/// Lightweight analytics and crash reporting service.
///
/// In production, replace the print statements with calls to your chosen
/// provider (Firebase Crashlytics, Sentry, Mixpanel, etc.).
/// This captures navigation events, user actions, and uncaught errors.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  bool _initialized = false;

  /// Initialize the analytics service. Call once at app startup.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Wire Flutter framework errors
    FlutterError.onError = (details) {
      logError('FlutterError', details.exception, details.stack);
      // In debug mode, also print to console
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      }
    };

    // Wire unhandled async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      logError('UncaughtAsync', error, stack);
      return true;
    };
  }

  /// Log a screen view / navigation event.
  void logScreenView(String screenName) {
    if (kDebugMode) {
      debugPrint('[Analytics] Screen: $screenName');
    }
    // TODO: Replace with provider call, e.g.:
    // FirebaseAnalytics.instance.logScreenView(screenName: screenName);
  }

  /// Log a custom event (button tap, action, etc.).
  void logEvent(String name, {Map<String, dynamic>? params}) {
    if (kDebugMode) {
      debugPrint('[Analytics] Event: $name ${params ?? ''}');
    }
    // TODO: Replace with provider call
  }

  /// Log user identification for crash reports.
  void setUser(String userId, {String? email, String? role}) {
    if (kDebugMode) {
      debugPrint('[Analytics] User: $userId ($role)');
    }
    // TODO: e.g. Sentry.configureScope((scope) => scope.setUser(SentryUser(id: userId)));
  }

  /// Log an error / exception.
  void logError(String tag, Object error, [StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('[Analytics] ERROR [$tag]: $error');
      if (stack != null) debugPrint(stack.toString());
    }
    // TODO: e.g. Sentry.captureException(error, stackTrace: stack);
  }
}
