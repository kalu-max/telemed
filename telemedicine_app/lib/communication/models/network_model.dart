import 'package:hive/hive.dart';

// Note: Hive generation removed - use manual serialization

/// Network type enumeration
enum NetworkType {
  wifi,
  mobile_4g,
  mobile_5g,
  mobile_3g,
  mobile_2g,
  unknown,
  none
}

/// Hive model for network quality metrics
@HiveType(typeId: 5)
class NetworkMetrics extends HiveObject {
  @HiveField(0)
  late NetworkType networkType;

  @HiveField(1)
  late int signalStrength; // 0-100 percentage

  @HiveField(2)
  late double downstreamBandwidth; // in Mbps

  @HiveField(3)
  late double upstreamBandwidth; // in Mbps

  @HiveField(4)
  late double latency; // in ms

  @HiveField(5)
  late double packetLoss; // 0-100 percentage

  @HiveField(6)
  late DateTime timestamp;

  @HiveField(7)
  late bool isStable; // determined by consistency of metrics

  @HiveField(8)
  late int rssValue; // RSSI for WiFi/cellular in dBm

  NetworkMetrics({
    required this.networkType,
    required this.signalStrength,
    required this.downstreamBandwidth,
    required this.upstreamBandwidth,
    required this.latency,
    required this.packetLoss,
    required this.timestamp,
    this.isStable = true,
    this.rssValue = 0,
  });

  Map<String, dynamic> toJson() => {
        'networkType': networkType.toString().split('.').last,
        'signalStrength': signalStrength,
        'downstreamBandwidth': downstreamBandwidth,
        'upstreamBandwidth': upstreamBandwidth,
        'latency': latency,
        'packetLoss': packetLoss,
        'timestamp': timestamp.toIso8601String(),
        'isStable': isStable,
        'rssValue': rssValue,
      };

  factory NetworkMetrics.fromJson(Map<String, dynamic> json) => NetworkMetrics(
        networkType: _parseNetworkType(json['networkType'] ?? 'unknown'),
        signalStrength: json['signalStrength'] ?? 0,
        downstreamBandwidth: (json['downstreamBandwidth'] ?? 0.0).toDouble(),
        upstreamBandwidth: (json['upstreamBandwidth'] ?? 0.0).toDouble(),
        latency: (json['latency'] ?? 0.0).toDouble(),
        packetLoss: (json['packetLoss'] ?? 0.0).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
        isStable: json['isStable'] ?? true,
        rssValue: json['rssValue'] ?? 0,
      );

  static NetworkType _parseNetworkType(String type) {
    switch (type) {
      case 'wifi':
        return NetworkType.wifi;
      case 'mobile_4g':
        return NetworkType.mobile_4g;
      case 'mobile_5g':
        return NetworkType.mobile_5g;
      case 'mobile_3g':
        return NetworkType.mobile_3g;
      case 'mobile_2g':
        return NetworkType.mobile_2g;
      case 'none':
        return NetworkType.none;
      default:
        return NetworkType.unknown;
    }
  }

  /// Get network quality rating 0-100
  int getQualityScore() {
    if (networkType == NetworkType.none) return 0;
    
    int score = 100;
    
    // Deduct for signal strength
    score -= (100 - signalStrength);
    
    // Deduct for packet loss
    score -= (packetLoss.toInt());
    
    // Deduct for high latency
    if (latency > 50) score -= 10;
    if (latency > 100) score -= 20;
    
    return score.clamp(0, 100);
  }

  /// Determine if network is suitable for HD video
  bool canSupportHDVideo() {
    return downstreamBandwidth >= 2.5 && 
           upstreamBandwidth >= 2.0 && 
           packetLoss < 2.0 &&
           latency < 50;
  }

  /// Determine if network is suitable for any video
  bool canSupportVideo() {
    return downstreamBandwidth >= 1.0 && 
           upstreamBandwidth >= 0.5 && 
           packetLoss < 5.0;
  }

  /// Determine if network is suitable for voice only
  bool canSupportVoice() {
    return downstreamBandwidth >= 0.1 && 
           upstreamBandwidth >= 0.1;
  }
}

/// Hive model for network history and trending
@HiveType(typeId: 6)
class NetworkHistory extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late List<NetworkMetrics> metrics;

  @HiveField(2)
  late DateTime startTime;

  @HiveField(3)
  late DateTime endTime;

  @HiveField(4)
  late String sessionId; // Associated call or message session

  NetworkHistory({
    required this.id,
    required this.metrics,
    required this.startTime,
    required this.endTime,
    required this.sessionId,
  });

  /// Calculate average metrics over the period
  NetworkMetrics getAverageMetrics() {
    if (metrics.isEmpty) {
      return NetworkMetrics(
        networkType: NetworkType.unknown,
        signalStrength: 0,
        downstreamBandwidth: 0,
        upstreamBandwidth: 0,
        latency: 0,
        packetLoss: 0,
        timestamp: DateTime.now(),
      );
    }

    double avgSignal = metrics.map((m) => m.signalStrength).reduce((a, b) => a + b) / metrics.length;
    double avgDownstream = metrics.map((m) => m.downstreamBandwidth).reduce((a, b) => a + b) / metrics.length;
    double avgUpstream = metrics.map((m) => m.upstreamBandwidth).reduce((a, b) => a + b) / metrics.length;
    double avgLatency = metrics.map((m) => m.latency).reduce((a, b) => a + b) / metrics.length;
    double avgPacketLoss = metrics.map((m) => m.packetLoss).reduce((a, b) => a + b) / metrics.length;

    return NetworkMetrics(
      networkType: metrics.last.networkType,
      signalStrength: avgSignal.toInt(),
      downstreamBandwidth: avgDownstream,
      upstreamBandwidth: avgUpstream,
      latency: avgLatency,
      packetLoss: avgPacketLoss,
      timestamp: DateTime.now(),
      isStable: calculateStability(),
    );
  }

  /// Calculate if the network is stable
  bool calculateStability() {
    if (metrics.length < 3) return true;
    
    // Check variation in key metrics
    final latencies = metrics.map((m) => m.latency).toList();
    final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
    final latencyVariation = latencies.map((l) => (l - avgLatency).abs()).reduce((a, b) => a + b) / latencies.length;
    
    // Stable if variation is less than 10% of average
    return latencyVariation < (avgLatency * 0.1);
  }
}
