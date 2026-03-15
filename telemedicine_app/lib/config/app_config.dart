/// Application Configuration
/// Centralized configuration for API endpoints, timeouts, and app constants
library;

import 'dart:convert';

class AppConfig {
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://telemed-backend.onrender.com',
  );
  
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://telemed-backend.onrender.com',
  );

  static const String iceServersJson = String.fromEnvironment(
    'ICE_SERVERS_JSON',
    defaultValue: '',
  );

  static const List<Map<String, dynamic>> _defaultIceServers = [
    {
      'urls': ['stun:stun.l.google.com:19302'],
    },
    {
      'urls': ['stun:stun1.l.google.com:19302'],
    },
  ];

  static List<Map<String, dynamic>> get iceServers {
    final rawValue = iceServersJson.trim();
    if (rawValue.isEmpty) {
      return _defaultIceServers;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is List) {
        final servers = decoded
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .where((entry) => entry['urls'] != null)
            .toList(growable: false);

        if (servers.isNotEmpty) {
          return servers;
        }
      }
    } catch (_) {
      // Keep STUN defaults when ICE_SERVERS_JSON is not valid JSON.
    }

    return _defaultIceServers;
  }

  // API Endpoints
  static const String authRegister = '/api/auth/register';
  static const String authLogin = '/api/auth/login';
  static const String authLogout = '/api/auth/logout';
  static const String authRefresh = '/api/auth/refresh';

  static const String callInitiate = '/api/calls/initiate';
  static const String callAnswer = '/api/calls/answer';
  static const String callReject = '/api/calls/reject';
  static const String callEnd = '/api/calls/end';
  static const String callHistory = '/api/calls/history';

  static const String usersGetDoctors = '/api/users/doctors/available';
  static const String usersGetAppointments = '/api/users/appointments';
  static const String usersBookAppointment = '/api/users/appointments/book';

  static const String metricsCallMetrics = '/api/metrics/call';
  static const String metricsUserStats = '/api/metrics/user/stats';
  static const String metricsNetworkPerformance = '/api/metrics/network/performance';

  // Network Configuration
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const int maxRetries = 3;

  // Video Call Configuration
  static const int defaultVideoWidth = 1280;
  static const int defaultVideoHeight = 720;
  static const int defaultFrameRate = 30;
  static const int defaultBitrate = 2500; // kbps

  // Network Quality Thresholds
  static const double excellentBandwidth = 5.0; // Mbps
  static const double goodBandwidth = 2.5;
  static const double fairBandwidth = 1.0;
  static const double poorBandwidth = 0.5;

  static const int excellentLatency = 50; // ms
  static const int goodLatency = 150;
  static const int fairLatency = 300;

  // Cache Configuration
  static const int cacheExpirationMinutes = 30;
  static const int maxCacheSize = 100;

  // App Version
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
}
