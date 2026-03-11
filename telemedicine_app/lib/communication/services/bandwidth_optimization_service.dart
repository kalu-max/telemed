import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../models/network_model.dart';
import '../models/call_model.dart';

/// Service for bandwidth monitoring and optimization
class BandwidthOptimizationService {
  final Connectivity _connectivity = Connectivity();
  
  late StreamController<NetworkMetrics> _metricsController;
  late StreamController<NetworkType> _networkTypeController;
  
  NetworkType _currentNetworkType = NetworkType.unknown;
  NetworkMetrics? _lastMetrics;
  Timer? _metricsTimer;
  
  static const Duration _metricsCheckInterval = Duration(seconds: 5);
  static const int _historySize = 100;
  
  final List<NetworkMetrics> _metricsHistory = [];
  
  BandwidthOptimizationService() {
    _metricsController = StreamController<NetworkMetrics>.broadcast();
    _networkTypeController = StreamController<NetworkType>.broadcast();
    _initializeNetworkMonitoring();
  }

  /// Start monitoring network changes
  void _initializeNetworkMonitoring() {
    _connectivity.onConnectivityChanged.listen((result) async {
      final ConnectivityResult single;
      if (result is List) {
        single = (result as List).isNotEmpty ? (result as List).first as ConnectivityResult : ConnectivityResult.none;
      } else {
        single = result;
      }
      final newNetworkType = await _mapConnectivityToNetworkType(single);
      if (newNetworkType != _currentNetworkType) {
        _currentNetworkType = newNetworkType;
        _networkTypeController.add(newNetworkType);
      }
    });
  }

  /// Map connectivity result to NetworkType
  Future<NetworkType> _mapConnectivityToNetworkType(ConnectivityResult result) async {
    switch (result) {
      case ConnectivityResult.wifi:
        return NetworkType.wifi;
      case ConnectivityResult.mobile:
        // Try to determine if 4G, 5G, 3G, or 2G
        return await _determineMobileNetworkType();
      case ConnectivityResult.none:
        return NetworkType.none;
      default:
        return NetworkType.unknown;
    }
  }

  /// Determine specific mobile network type (requires Android API 29+)
  Future<NetworkType> _determineMobileNetworkType() async {
    // Note: Full implementation would require platform-specific channels
    // For now, return a default mobile type that can be upgraded
    return NetworkType.mobile_4g;
  }

  /// Start periodic bandwidth monitoring
  void startBandwidthMonitoring() {
    if (_metricsTimer != null) return;
    
    _metricsTimer = Timer.periodic(_metricsCheckInterval, (_) async {
      final metrics = await _measureNetworkMetrics();
      _metricsHistory.add(metrics);
      
      // Keep history size manageable
      if (_metricsHistory.length > _historySize) {
        _metricsHistory.removeAt(0);
      }
      
      _lastMetrics = metrics;
      _metricsController.add(metrics);
    });
  }

  /// Stop bandwidth monitoring
  void stopBandwidthMonitoring() {
    _metricsTimer?.cancel();
    _metricsTimer = null;
  }

  /// Measure current network metrics using simplified approach
  /// Note: Full implementation would use actual network measurement tools
  Future<NetworkMetrics> _measureNetworkMetrics() async {
    final networkType = _currentNetworkType;
    
    // Simulated metrics - would be replaced with actual measurement
    final (downBandwidth, upBandwidth) = _estimateBandwidth(networkType);
    
    return NetworkMetrics(
      networkType: networkType,
      signalStrength: await _estimateSignalStrength(networkType),
      downstreamBandwidth: downBandwidth,
      upstreamBandwidth: upBandwidth,
      latency: await _estimateLatency(networkType),
      packetLoss: 0.0,
      timestamp: DateTime.now(),
    );
  }

  /// Estimate bandwidth based on network type
  (double, double) _estimateBandwidth(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
        return (50.0, 50.0); // Mbps
      case NetworkType.mobile_5g:
        return (100.0, 50.0);
      case NetworkType.mobile_4g:
        return (10.0, 5.0);
      case NetworkType.mobile_3g:
        return (1.0, 0.5);
      case NetworkType.mobile_2g:
        return (0.1, 0.05);
      case NetworkType.none:
        return (0.0, 0.0);
      default:
        return (0.0, 0.0);
    }
  }

  /// Estimate signal strength (requires platform channels for real data)
  Future<int> _estimateSignalStrength(NetworkType type) async {
    switch (type) {
      case NetworkType.wifi:
        return 85;
      case NetworkType.mobile_5g:
        return 90;
      case NetworkType.mobile_4g:
        return 75;
      case NetworkType.mobile_3g:
        return 60;
      case NetworkType.mobile_2g:
        return 40;
      case NetworkType.none:
        return 0;
      default:
        return 0;
    }
  }

  /// Estimate network latency
  Future<double> _estimateLatency(NetworkType type) async {
    switch (type) {
      case NetworkType.wifi:
        return 20.0; // ms
      case NetworkType.mobile_5g:
        return 30.0;
      case NetworkType.mobile_4g:
        return 50.0;
      case NetworkType.mobile_3g:
        return 100.0;
      case NetworkType.mobile_2g:
        return 200.0;
      case NetworkType.none:
        return 9999.0;
      default:
        return 0.0;
    }
  }

  /// Select optimal video quality based on network conditions
  VideoQuality selectOptimalVideoQuality(NetworkMetrics metrics) {
    if (metrics.canSupportHDVideo()) {
      return VideoQuality.high;
    } else if (metrics.canSupportVideo()) {
      return VideoQuality.medium;
    } else {
      return VideoQuality.low;
    }
  }

  /// Get recommended bitrate for audio based on bandwidth
  int getRecommendedAudioBitrate(NetworkMetrics metrics) {
    // Opus codec bitrates (high quality to low bandwidth)
    if (metrics.upstreamBandwidth >= 0.128) {
      return 128000; // Full quality: 128 kbps
    } else if (metrics.upstreamBandwidth >= 0.064) {
      return 64000; // Good quality: 64 kbps
    } else if (metrics.upstreamBandwidth >= 0.032) {
      return 32000; // Medium quality: 32 kbps
    } else {
      return 16000; // Low quality: 16 kbps (still intelligible)
    }
  }

  /// Determine if network transition is needed
  bool requiresNetworkTransition(NetworkMetrics current, NetworkMetrics threshold) {
    final qualityDifference = current.getQualityScore() - threshold.getQualityScore();
    return qualityDifference > 20; // Transition if quality drops >20 points
  }

  /// Get network type stream
  Stream<NetworkType> get networkTypeStream => _networkTypeController.stream;

  /// Get metrics stream
  Stream<NetworkMetrics> get metricsStream => _metricsController.stream;

  /// Get current network type
  NetworkType get currentNetworkType => _currentNetworkType;

  /// Get last measured metrics
  NetworkMetrics? get lastMetrics => _lastMetrics;

  /// Get metrics history
  List<NetworkMetrics> get metricsHistory => List.unmodifiable(_metricsHistory);

  /// Calculate moving average of key metrics
  NetworkMetrics getMovingAverageMetrics({int windowSize = 10}) {
    if (_metricsHistory.isEmpty) {
      return _lastMetrics ??
          NetworkMetrics(
            networkType: NetworkType.unknown,
            signalStrength: 0,
            downstreamBandwidth: 0,
            upstreamBandwidth: 0,
            latency: 0,
            packetLoss: 0,
            timestamp: DateTime.now(),
          );
    }

    final window = _metricsHistory.sublist(
      (_metricsHistory.length > windowSize) ? _metricsHistory.length - windowSize : 0,
    );

    final avgSignal = window.map((m) => m.signalStrength).reduce((a, b) => a + b) / window.length;
    final avgDownstream = window.map((m) => m.downstreamBandwidth).reduce((a, b) => a + b) / window.length;
    final avgUpstream = window.map((m) => m.upstreamBandwidth).reduce((a, b) => a + b) / window.length;
    final avgLatency = window.map((m) => m.latency).reduce((a, b) => a + b) / window.length;
    final avgPacketLoss = window.map((m) => m.packetLoss).reduce((a, b) => a + b) / window.length;

    return NetworkMetrics(
      networkType: window.last.networkType,
      signalStrength: avgSignal.toInt(),
      downstreamBandwidth: avgDownstream,
      upstreamBandwidth: avgUpstream,
      latency: avgLatency,
      packetLoss: avgPacketLoss,
      timestamp: DateTime.now(),
      isStable: _calculateStability(window),
    );
  }

  /// Check network stability
  bool _calculateStability(List<NetworkMetrics> metrics) {
    if (metrics.length < 3) return true;

    final latencies = metrics.map((m) => m.latency).toList();
    final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
    final latencyVariation = latencies.map((l) => (l - avgLatency).abs()).reduce((a, b) => a + b) / latencies.length;

    return latencyVariation < (avgLatency * 0.2); // 20% tolerance
  }

  /// Cleanup resources
  void dispose() {
    stopBandwidthMonitoring();
    _metricsController.close();
    _networkTypeController.close();
  }
}
