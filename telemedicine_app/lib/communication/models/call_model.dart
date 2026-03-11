import 'package:hive/hive.dart';

// Note: Hive generation removed - use manual serialization

/// Enumeration for call types
enum CallType { audio, video, groupVideo }

/// Enumeration for call status
enum CallStatus {
  initiating,
  ringing,
  accepted,
  connecting,
  connected,
  disconnecting,
  disconnected,
  rejected,
  missed,
  failed,
  ended
}

/// Enumeration for call direction
enum CallDirection { incoming, outgoing }

/// Video quality levels with corresponding bitrates and resolutions
enum VideoQuality {
  low(bitrate: 500000, width: 320, height: 240, fps: 15),
  medium(bitrate: 1500000, width: 640, height: 480, fps: 24),
  high(bitrate: 2500000, width: 1280, height: 720, fps: 30);

  final int bitrate;
  final int width;
  final int height;
  final int fps;

  const VideoQuality({
    required this.bitrate,
    required this.width,
    required this.height,
    required this.fps,
  });
}

/// Hive model for call sessions
@HiveType(typeId: 3)
class CallSession extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String callerId;

  @HiveField(2)
  late String callerName;

  @HiveField(3)
  late String? callerAvatarUrl;

  @HiveField(4)
  late String receiverId;

  @HiveField(5)
  late String receiverName;

  @HiveField(6)
  late String? receiverAvatarUrl;

  @HiveField(7)
  late CallType callType;

  @HiveField(8)
  late CallStatus status;

  @HiveField(9)
  late CallDirection direction;

  @HiveField(10)
  late DateTime initiatedAt;

  @HiveField(11)
  late DateTime? startedAt;

  @HiveField(12)
  late DateTime? endedAt;

  @HiveField(13)
  late Duration? duration;

  @HiveField(14)
  late List<String> participantIds; // For group calls

  @HiveField(15)
  late bool isEncrypted;

  CallSession({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerAvatarUrl,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatarUrl,
    this.callType = CallType.audio,
    this.status = CallStatus.initiating,
    required this.direction,
    required this.initiatedAt,
    this.startedAt,
    this.endedAt,
    this.duration,
    List<String>? participantIds,
    this.isEncrypted = true,
  }) : participantIds = participantIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'callerId': callerId,
        'callerName': callerName,
        'callerAvatarUrl': callerAvatarUrl,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'receiverAvatarUrl': receiverAvatarUrl,
        'callType': callType.toString().split('.').last,
        'status': status.toString().split('.').last,
        'direction': direction.toString().split('.').last,
        'initiatedAt': initiatedAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'duration': duration?.inSeconds,
        'participantIds': participantIds,
        'isEncrypted': isEncrypted,
      };

  factory CallSession.fromJson(Map<String, dynamic> json) => CallSession(
        id: json['id'] ?? '',
        callerId: json['callerId'] ?? '',
        callerName: json['callerName'] ?? '',
        callerAvatarUrl: json['callerAvatarUrl'],
        receiverId: json['receiverId'] ?? '',
        receiverName: json['receiverName'] ?? '',
        receiverAvatarUrl: json['receiverAvatarUrl'],
        callType: _parseCallType(json['callType'] ?? 'audio'),
        status: _parseCallStatus(json['status'] ?? 'initiating'),
        direction: _parseCallDirection(json['direction'] ?? 'outgoing'),
        initiatedAt: DateTime.parse(json['initiatedAt'] ?? DateTime.now().toIso8601String()),
        startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
        endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
        duration: json['duration'] != null ? Duration(seconds: json['duration']) : null,
        participantIds: List<String>.from(json['participantIds'] ?? []),
        isEncrypted: json['isEncrypted'] ?? true,
      );

  static CallType _parseCallType(String type) {
    switch (type) {
      case 'video':
        return CallType.video;
      case 'groupVideo':
        return CallType.groupVideo;
      default:
        return CallType.audio;
    }
  }

  static CallStatus _parseCallStatus(String status) {
    switch (status) {
      case 'ringing':
        return CallStatus.ringing;
      case 'accepted':
        return CallStatus.accepted;
      case 'connecting':
        return CallStatus.connecting;
      case 'connected':
        return CallStatus.connected;
      case 'disconnecting':
        return CallStatus.disconnecting;
      case 'disconnected':
        return CallStatus.disconnected;
      case 'rejected':
        return CallStatus.rejected;
      case 'missed':
        return CallStatus.missed;
      case 'failed':
        return CallStatus.failed;
      case 'ended':
        return CallStatus.ended;
      default:
        return CallStatus.initiating;
    }
  }

  static CallDirection _parseCallDirection(String direction) {
    return direction == 'incoming' ? CallDirection.incoming : CallDirection.outgoing;
  }
}

/// Model for call statistics and monitoring
@HiveType(typeId: 4)
class CallStatistics extends HiveObject {
  @HiveField(0)
  late String callId;

  @HiveField(1)
  late double avgBitrate; // in kbps

  @HiveField(2)
  late double avgLatency; // in ms

  @HiveField(3)
  late double packetLoss; // percentage

  @HiveField(4)
  late double jitter; // in ms

  @HiveField(5)
  late double audioLevel;

  @HiveField(6)
  late int videoFps;

  @HiveField(7)
  late VideoQuality currentVideoQuality;

  @HiveField(8)
  late DateTime timestamp;

  @HiveField(9)
  late int totalPacketsLost;

  @HiveField(10)
  late int totalPacketsReceived;

  CallStatistics({
    required this.callId,
    this.avgBitrate = 0.0,
    this.avgLatency = 0.0,
    this.packetLoss = 0.0,
    this.jitter = 0.0,
    this.audioLevel = 0.0,
    this.videoFps = 0,
    this.currentVideoQuality = VideoQuality.medium,
    required this.timestamp,
    this.totalPacketsLost = 0,
    this.totalPacketsReceived = 0,
  });

  Map<String, dynamic> toJson() => {
        'callId': callId,
        'avgBitrate': avgBitrate,
        'avgLatency': avgLatency,
        'packetLoss': packetLoss,
        'jitter': jitter,
        'audioLevel': audioLevel,
        'videoFps': videoFps,
        'currentVideoQuality': currentVideoQuality.toString().split('.').last,
        'timestamp': timestamp.toIso8601String(),
        'totalPacketsLost': totalPacketsLost,
        'totalPacketsReceived': totalPacketsReceived,
      };
}
