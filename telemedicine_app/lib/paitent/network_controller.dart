import 'package:flutter/foundation.dart';

enum NetworkType { wifi, cellular, unknown, none }

enum NetworkQuality { excellent, good, fair, poor, veryPoor }

class NetworkInfo {
  final NetworkType type;
  final NetworkQuality quality;
  final double bandwidth; // in Mbps
  final int latency; // in ms
  final int signalStrength; // 0-100%

  NetworkInfo({
    required this.type,
    required this.quality,
    required this.bandwidth,
    required this.latency,
    required this.signalStrength,
  });
}

/// Simplified network controller - simulates network quality
class MultiNetworkController extends ChangeNotifier {
  NetworkInfo? _currentNetwork;

  MultiNetworkController() {
    _initialize();
  }

  NetworkInfo? get currentNetwork => _currentNetwork;

  void _initialize() {
    // Start with good WiFi connection
    _currentNetwork = NetworkInfo(
      type: NetworkType.wifi,
      quality: NetworkQuality.excellent,
      bandwidth: 50.0,
      latency: 20,
      signalStrength: 95,
    );
  }

  /// Simulate network quality change (for testing)
  void simulateNetworkCondition(NetworkQuality quality) {
    late int latency;
    late int signal;
    late double bandwidth;

    switch (quality) {
      case NetworkQuality.excellent:
        latency = 20;
        signal = 95;
        bandwidth = 50.0;
        break;
      case NetworkQuality.good:
        latency = 50;
        signal = 75;
        bandwidth = 25.0;
        break;
      case NetworkQuality.fair:
        latency = 100;
        signal = 50;
        bandwidth = 5.0;
        break;
      case NetworkQuality.poor:
        latency = 150;
        signal = 25;
        bandwidth = 1.0;
        break;
      case NetworkQuality.veryPoor:
        latency = 250;
        signal = 10;
        bandwidth = 0.5;
        break;
    }

    _currentNetwork = NetworkInfo(
      type: NetworkType.wifi,
      quality: quality,
      bandwidth: bandwidth,
      latency: latency,
      signalStrength: signal,
    );
    notifyListeners();
  }

  double getAverageBandwidth() => _currentNetwork?.bandwidth ?? 0;
  int getAverageLatency() => _currentNetwork?.latency ?? 0;
  bool isDualNetworkAvailable() => false;

  String getQualityDescription(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return 'Excellent';
      case NetworkQuality.good:
        return 'Good';
      case NetworkQuality.fair:
        return 'Fair';
      case NetworkQuality.poor:
        return 'Poor';
      case NetworkQuality.veryPoor:
        return 'Very Poor';
    }
  }
}
