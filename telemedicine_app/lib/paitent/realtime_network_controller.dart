import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkType { wifi, cellular4g, cellular5g, cellular3g, unknown, none }

enum NetworkQuality { excellent, good, fair, poor, veryPoor }

class NetworkInfo {
  final NetworkType type;
  final NetworkQuality quality;
  final double bandwidth; // in Mbps
  final int latency; // in ms
  final int signalStrength; // 0-100%
  final String? ssid; // For WiFi
  final bool isDualNetwork;
  final DateTime timestamp;

  NetworkInfo({
    required this.type,
    required this.quality,
    required this.bandwidth,
    required this.latency,
    required this.signalStrength,
    this.ssid,
    this.isDualNetwork = false,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'NetworkInfo(type: $type, quality: $quality, bandwidth: ${bandwidth.toStringAsFixed(2)}Mbps, latency: ${latency}ms, signal: $signalStrength%)';
  }
}

class RealTimeNetworkController extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  
  late NetworkInfo _currentNetwork;
  
  final List<NetworkInfo> _networkHistory = [];
  static const int maxHistorySize = 50;
  
  Timer? _metricsUpdateTimer;

  bool _isWifiAvailable = false;
  bool _isCellularAvailable = false;

  RealTimeNetworkController() {
    _currentNetwork = _getDefaultNetworkInfo();
    _initialize();
  }

  NetworkInfo get currentNetwork => _currentNetwork;
  List<NetworkInfo> get networkHistory => _networkHistory;
  bool get isWifiAvailable => _isWifiAvailable;
  bool get isCellularAvailable => _isCellularAvailable;
  bool get isDualNetworkAvailable => _isWifiAvailable && _isCellularAvailable;

  void _initialize() {
    // Listen to real connectivity changes
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      final dynamic r = result;
      final ConnectivityResult single;
      if (r is List) {
        single = r.isNotEmpty ? r.first as ConnectivityResult : ConnectivityResult.none;
      } else {
        single = r as ConnectivityResult;
      }
      _handleConnectivityChange(single);
    });

    // Check initial state
    _checkInitialConnectivity();

    // Periodic refresh to keep stats current
    _metricsUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshMetrics();
    });
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final dynamic result = await _connectivity.checkConnectivity();
      final ConnectivityResult single;
      if (result is List) {
        single = result.isNotEmpty ? result.first as ConnectivityResult : ConnectivityResult.none;
      } else {
        single = result as ConnectivityResult;
      }
      _handleConnectivityChange(single);
    } catch (e) {
      debugPrint('Error checking initial connectivity: $e');
    }
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    final type = _mapResult(result);
    _isWifiAvailable = result == ConnectivityResult.wifi;
    _isCellularAvailable = result == ConnectivityResult.mobile;

    final (bandwidth, latency, signal) = _estimateForType(type);
    final quality = _determineQuality(bandwidth, latency);

    _currentNetwork = NetworkInfo(
      type: type,
      quality: quality,
      bandwidth: bandwidth,
      latency: latency,
      signalStrength: signal,
      isDualNetwork: isDualNetworkAvailable,
      timestamp: DateTime.now(),
    );

    _addToHistory(_currentNetwork);
    notifyListeners();
  }

  NetworkType _mapResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return NetworkType.wifi;
      case ConnectivityResult.mobile:
        return NetworkType.cellular4g;
      case ConnectivityResult.none:
        return NetworkType.none;
      default:
        return NetworkType.unknown;
    }
  }

  /// Estimate metrics based on detected network type.
  /// Platform-specific signal APIs would give real values; this provides
  /// reasonable defaults so the UI shows meaningful data rather than
  /// random noise.
  (double bandwidth, int latency, int signal) _estimateForType(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
        return (50.0, 20, 85);
      case NetworkType.cellular5g:
        return (100.0, 15, 90);
      case NetworkType.cellular4g:
        return (15.0, 50, 75);
      case NetworkType.cellular3g:
        return (2.0, 120, 55);
      case NetworkType.none:
        return (0.0, 9999, 0);
      case NetworkType.unknown:
        return (5.0, 100, 50);
    }
  }

  void _refreshMetrics() {
    // Re-emit with updated timestamp so UI stays fresh
    final (bandwidth, latency, signal) = _estimateForType(_currentNetwork.type);
    final quality = _determineQuality(bandwidth, latency);

    _currentNetwork = NetworkInfo(
      type: _currentNetwork.type,
      quality: quality,
      bandwidth: bandwidth,
      latency: latency,
      signalStrength: signal,
      isDualNetwork: isDualNetworkAvailable,
      timestamp: DateTime.now(),
    );

    _addToHistory(_currentNetwork);
    notifyListeners();
  }

  NetworkQuality _determineQuality(double bandwidth, int latency) {
    if (bandwidth >= 2.5 && latency <= 50) {
      return NetworkQuality.excellent;
    } else if (bandwidth >= 1.5 && latency <= 100) {
      return NetworkQuality.good;
    } else if (bandwidth >= 0.8 && latency <= 150) {
      return NetworkQuality.fair;
    } else if (bandwidth >= 0.4 && latency <= 250) {
      return NetworkQuality.poor;
    } else {
      return NetworkQuality.veryPoor;
    }
  }

  void _addToHistory(NetworkInfo info) {
    _networkHistory.add(info);
    if (_networkHistory.length > maxHistorySize) {
      _networkHistory.removeAt(0);
    }
  }

  NetworkInfo _getDefaultNetworkInfo() {
    return NetworkInfo(
      type: NetworkType.unknown,
      quality: NetworkQuality.fair,
      bandwidth: 5.0,
      latency: 100,
      signalStrength: 50,
      isDualNetwork: false,
      timestamp: DateTime.now(),
    );
  }

  double getAverageBandwidth() {
    if (_networkHistory.isEmpty) return _currentNetwork.bandwidth;
    double sum = 0;
    for (var info in _networkHistory) {
      sum += info.bandwidth;
    }
    return sum / _networkHistory.length;
  }

  int getAverageLatency() {
    if (_networkHistory.isEmpty) return _currentNetwork.latency;
    int sum = 0;
    for (var info in _networkHistory) {
      sum += info.latency;
    }
    return sum ~/ _networkHistory.length;
  }

  NetworkQuality getPredictedQuality() {
    if (_networkHistory.length < 3) return _currentNetwork.quality;

    final recent = _networkHistory.sublist(
      _networkHistory.length > 5 ? _networkHistory.length - 5 : 0,
    );

    double avgBandwidth = recent.fold(0.0, (sum, info) => sum + info.bandwidth) / recent.length;
    int avgLatency = (recent.fold(0, (sum, info) => sum + info.latency) / recent.length).toInt();

    return _determineQuality(avgBandwidth, avgLatency);
  }

  List<double> getBandwidthTrend() {
    return _networkHistory.map((info) => info.bandwidth).toList();
  }

  List<int> getLatencyTrend() {
    return _networkHistory.map((info) => info.latency).toList();
  }

  String getQualityDescription(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return 'Excellent - Perfect for HD video';
      case NetworkQuality.good:
        return 'Good - Suitable for standard video';
      case NetworkQuality.fair:
        return 'Fair - Reduced quality recommended';
      case NetworkQuality.poor:
        return 'Poor - Low bandwidth, audio focus';
      case NetworkQuality.veryPoor:
        return 'Very Poor - Minimal streaming';
    }
  }

  String getNetworkTypeDescription(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
        return 'WiFi';
      case NetworkType.cellular4g:
        return '4G/LTE';
      case NetworkType.cellular5g:
        return '5G';
      case NetworkType.cellular3g:
        return '3G';
      case NetworkType.unknown:
        return 'Unknown';
      case NetworkType.none:
        return 'No Connection';
    }
  }

  @override
  void dispose() {
    _metricsUpdateTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
