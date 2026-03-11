import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class ServerConfig {
  static const String _serverUrlKey = 'server_url';

  static Future<String> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(_serverUrlKey);
    if (savedValue == null || savedValue.trim().isEmpty) {
      return AppConfig.apiBaseUrl;
    }

    return normalizeUrl(savedValue);
  }

  static Future<String> getWsBaseUrl() async {
    final apiBaseUrl = await getApiBaseUrl();
    return toWebSocketUrl(apiBaseUrl);
  }

  static Future<void> saveApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, normalizeUrl(url));
  }

  static String normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return AppConfig.apiBaseUrl;
    }

    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  static String toWebSocketUrl(String url) {
    final normalized = normalizeUrl(url);
    if (normalized.startsWith('https://')) {
      return 'wss://${normalized.substring('https://'.length)}';
    }
    if (normalized.startsWith('http://')) {
      return 'ws://${normalized.substring('http://'.length)}';
    }
    if (normalized.startsWith('wss://') || normalized.startsWith('ws://')) {
      return normalized;
    }
    return AppConfig.wsBaseUrl;
  }
}