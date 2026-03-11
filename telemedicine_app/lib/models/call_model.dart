/// Call Model
/// Represents a video call session
library;

enum CallStatus {
  idle,
  ringing,
  connecting,
  connected,
  disconnected,
  failed,
  rejected,
}

enum CallType {
  audio,
  video,
}

class Call {
  final String id;
  final String initiatorId;
  final String recipientId;
  final String initiatorName;
  final String recipientName;
  final String? initiatorAvatar;
  final String? recipientAvatar;
  final CallType type;
  final CallStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration duration;
  final String? rejectionReason;

  Call({
    required this.id,
    required this.initiatorId,
    required this.recipientId,
    required this.initiatorName,
    required this.recipientName,
    this.initiatorAvatar,
    this.recipientAvatar,
    required this.type,
    required this.status,
    required this.startTime,
    this.endTime,
    Duration? duration,
    this.rejectionReason,
  }) : duration = duration ?? Duration.zero;

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      id: json['id'] as String? ?? '',
      initiatorId: json['initiatorId'] as String? ?? '',
      recipientId: json['recipientId'] as String? ?? '',
      initiatorName: json['initiatorName'] as String? ?? '',
      recipientName: json['recipientName'] as String? ?? '',
      initiatorAvatar: json['initiatorAvatar'] as String?,
      recipientAvatar: json['recipientAvatar'] as String?,
      type: json['type'] == 'video' ? CallType.video : CallType.audio,
      status: CallStatus.values[json['status'] as int? ?? 0],
      startTime: json['startTime'] != null 
        ? DateTime.parse(json['startTime'] as String) 
        : DateTime.now(),
      endTime: json['endTime'] != null 
        ? DateTime.parse(json['endTime'] as String) 
        : null,
      duration: json['duration'] != null 
        ? Duration(seconds: json['duration'] as int) 
        : Duration.zero,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'initiatorId': initiatorId,
    'recipientId': recipientId,
    'initiatorName': initiatorName,
    'recipientName': recipientName,
    'initiatorAvatar': initiatorAvatar,
    'recipientAvatar': recipientAvatar,
    'type': type == CallType.video ? 'video' : 'audio',
    'status': status.index,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'duration': duration.inSeconds,
    'rejectionReason': rejectionReason,
  };
}

/// Call Metrics Model
class CallMetrics {
  final String callId;
  final String timestamp;
  final String videoResolution;
  final int frameRate;
  final int bitrate;
  final int latency;
  final double packetLoss;
  final double bandwidth;
  final int qualityScore;

  CallMetrics({
    required this.callId,
    required this.timestamp,
    required this.videoResolution,
    required this.frameRate,
    required this.bitrate,
    required this.latency,
    required this.packetLoss,
    required this.bandwidth,
    required this.qualityScore,
  });

  factory CallMetrics.fromJson(Map<String, dynamic> json) {
    return CallMetrics(
      callId: json['callId'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      videoResolution: json['videoResolution'] as String? ?? '720p',
      frameRate: json['frameRate'] as int? ?? 30,
      bitrate: json['bitrate'] as int? ?? 2500,
      latency: json['latency'] as int? ?? 0,
      packetLoss: (json['packetLoss'] as num?)?.toDouble() ?? 0.0,
      bandwidth: (json['bandwidth'] as num?)?.toDouble() ?? 0.0,
      qualityScore: json['qualityScore'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'callId': callId,
    'timestamp': timestamp,
    'videoResolution': videoResolution,
    'frameRate': frameRate,
    'bitrate': bitrate,
    'latency': latency,
    'packetLoss': packetLoss,
    'bandwidth': bandwidth,
    'qualityScore': qualityScore,
  };
}
