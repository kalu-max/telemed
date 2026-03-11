import 'dart:convert';

class AppConfig {
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
}
