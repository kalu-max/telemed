import 'package:hive/hive.dart';

// Note: Hive generation removed - use manual serialization

/// Enumeration for doctor availability status
enum PresenceStatus {
  online,      // Available for consultation
  busy,        // In active consultation
  away,        // Away but might return soon
  doNotDisturb, // Do not disturb
  offline      // Offline
}

/// Enumeration for consultation type availability
enum ConsultationType {
  videoCall,   // Video consultation available
  audioCall,   // Audio/voice consultation available
  chat,        // Text chat available
  all          // All types available
}

/// Doctor presence and availability information
@HiveType(typeId: 50)
class DoctorPresence extends HiveObject {
  @HiveField(0)
  final String doctorId;

  @HiveField(1)
  final String doctorName;

  @HiveField(2)
  final String specialty;

  @HiveField(3)
  final String? profileImageUrl;

  @HiveField(4)
  final PresenceStatus status;

  @HiveField(5)
  final ConsultationType consultationType;

  @HiveField(6)
  final double? ratingScore;

  @HiveField(7)
  final int? totalConsultations;

  @HiveField(8)
  final int? responseTimeSeconds;

  @HiveField(9)
  final String? currentPatientId;

  @HiveField(10)
  final DateTime lastSeen;

  @HiveField(11)
  final DateTime? availableUntil;

  @HiveField(12)
  final bool isVerified;

  @HiveField(13)
  final int? consultationFee;

  @HiveField(14)
  final List<String>? languages;

  @HiveField(15)
  final String? bio;

  @HiveField(16)
  final bool acceptsEmergency;

  DoctorPresence({
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    this.profileImageUrl,
    required this.status,
    required this.consultationType,
    this.ratingScore,
    this.totalConsultations,
    this.responseTimeSeconds,
    this.currentPatientId,
    required this.lastSeen,
    this.availableUntil,
    required this.isVerified,
    this.consultationFee,
    this.languages,
    this.bio,
    required this.acceptsEmergency,
  });

  /// Check if doctor is immediately available for consultation
  bool get isAvailable => status == PresenceStatus.online;

  /// Check if doctor is currently in consultation
  bool get isBusy => status == PresenceStatus.busy;

  /// Get display name for status
  String get statusLabel {
    switch (status) {
      case PresenceStatus.online:
        return 'Online';
      case PresenceStatus.busy:
        return 'In Consultation';
      case PresenceStatus.away:
        return 'Away';
      case PresenceStatus.doNotDisturb:
        return 'Do Not Disturb';
      case PresenceStatus.offline:
        return 'Offline';
    }
  }

  /// Calculate availability score (0-100) for sorting
  int get availabilityScore {
    if (!isAvailable) return 0;
    
    int score = 100;
    
    // Reduce score if away
    if (status == PresenceStatus.away) score -= 20;
    
    // Reduce score based on response time (slower = lower score)
    if (responseTimeSeconds != null) {
      if (responseTimeSeconds! > 300) score -= 10; // > 5 min
      if (responseTimeSeconds! > 600) score -= 15; // > 10 min
    }
    
    return score.clamp(0, 100);
  }

  /// Create a copy with updated fields
  DoctorPresence copyWith({
    String? doctorId,
    String? doctorName,
    String? specialty,
    String? profileImageUrl,
    PresenceStatus? status,
    ConsultationType? consultationType,
    double? ratingScore,
    int? totalConsultations,
    int? responseTimeSeconds,
    String? currentPatientId,
    DateTime? lastSeen,
    DateTime? availableUntil,
    bool? isVerified,
    int? consultationFee,
    List<String>? languages,
    String? bio,
    bool? acceptsEmergency,
  }) {
    return DoctorPresence(
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      specialty: specialty ?? this.specialty,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      status: status ?? this.status,
      consultationType: consultationType ?? this.consultationType,
      ratingScore: ratingScore ?? this.ratingScore,
      totalConsultations: totalConsultations ?? this.totalConsultations,
      responseTimeSeconds: responseTimeSeconds ?? this.responseTimeSeconds,
      currentPatientId: currentPatientId ?? this.currentPatientId,
      lastSeen: lastSeen ?? this.lastSeen,
      availableUntil: availableUntil ?? this.availableUntil,
      isVerified: isVerified ?? this.isVerified,
      consultationFee: consultationFee ?? this.consultationFee,
      languages: languages ?? this.languages,
      bio: bio ?? this.bio,
      acceptsEmergency: acceptsEmergency ?? this.acceptsEmergency,
    );
  }

  /// Convert to JSON for API communication
  Map<String, dynamic> toJson() => {
    'doctorId': doctorId,
    'doctorName': doctorName,
    'specialty': specialty,
    'profileImageUrl': profileImageUrl,
    'status': status.toString().split('.').last,
    'consultationType': consultationType.toString().split('.').last,
    'ratingScore': ratingScore,
    'totalConsultations': totalConsultations,
    'responseTimeSeconds': responseTimeSeconds,
    'currentPatientId': currentPatientId,
    'lastSeen': lastSeen.toIso8601String(),
    'availableUntil': availableUntil?.toIso8601String(),
    'isVerified': isVerified,
    'consultationFee': consultationFee,
    'languages': languages,
    'bio': bio,
    'acceptsEmergency': acceptsEmergency,
  };

  /// Create from JSON
  factory DoctorPresence.fromJson(Map<String, dynamic> json) {
    return DoctorPresence(
      doctorId: json['doctorId'] as String,
      doctorName: json['doctorName'] as String,
      specialty: json['specialty'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
      status: _parsePresenceStatus(json['status']),
      consultationType: _parseConsultationType(json['consultationType']),
      ratingScore: (json['ratingScore'] as num?)?.toDouble(),
      totalConsultations: json['totalConsultations'] as int?,
      responseTimeSeconds: json['responseTimeSeconds'] as int?,
      currentPatientId: json['currentPatientId'] as String?,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      availableUntil: json['availableUntil'] != null 
          ? DateTime.parse(json['availableUntil'] as String) 
          : null,
      isVerified: json['isVerified'] as bool? ?? false,
      consultationFee: json['consultationFee'] as int?,
      languages: List<String>.from(json['languages'] as List? ?? []),
      bio: json['bio'] as String?,
      acceptsEmergency: json['acceptsEmergency'] as bool? ?? false,
    );
  }

  static PresenceStatus _parsePresenceStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'online':
        return PresenceStatus.online;
      case 'busy':
        return PresenceStatus.busy;
      case 'away':
        return PresenceStatus.away;
      case 'donotdisturb':
        return PresenceStatus.doNotDisturb;
      case 'offline':
      default:
        return PresenceStatus.offline;
    }
  }

  static ConsultationType _parseConsultationType(String? type) {
    switch (type?.toLowerCase()) {
      case 'videocall':
        return ConsultationType.videoCall;
      case 'audiocall':
        return ConsultationType.audioCall;
      case 'chat':
        return ConsultationType.chat;
      case 'all':
      default:
        return ConsultationType.all;
    }
  }
}

/// Presence update event (for real-time updates)
class PresenceUpdate {
  final String doctorId;
  final PresenceStatus newStatus;
  final DateTime timestamp;

  PresenceUpdate({
    required this.doctorId,
    required this.newStatus,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'doctorId': doctorId,
    'newStatus': newStatus.toString().split('.').last,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Schedule time slot for doctor availability
@HiveType(typeId: 51)
class AvailabilitySlot extends HiveObject {
  @HiveField(0)
  final String slotId;

  @HiveField(1)
  final String doctorId;

  @HiveField(2)
  final DateTime startTime;

  @HiveField(3)
  final DateTime endTime;

  @HiveField(4)
  final bool isBooked;

  @HiveField(5)
  final String? bookedByPatientId;

  @HiveField(6)
  final ConsultationType consultationType;

  @HiveField(7)
  final int maxPatients;

  @HiveField(8)
  final int currentPatientCount;

  AvailabilitySlot({
    required this.slotId,
    required this.doctorId,
    required this.startTime,
    required this.endTime,
    required this.isBooked,
    this.bookedByPatientId,
    required this.consultationType,
    required this.maxPatients,
    required this.currentPatientCount,
  });

  bool get hasAvailability => currentPatientCount < maxPatients;

  bool get isExpired => DateTime.now().isAfter(endTime);

  Duration duration() => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
    'slotId': slotId,
    'doctorId': doctorId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'isBooked': isBooked,
    'bookedByPatientId': bookedByPatientId,
    'consultationType': consultationType.toString().split('.').last,
    'maxPatients': maxPatients,
    'currentPatientCount': currentPatientCount,
  };

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      slotId: json['slotId'] as String,
      doctorId: json['doctorId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      isBooked: json['isBooked'] as bool? ?? false,
      bookedByPatientId: json['bookedByPatientId'] as String?,
      consultationType: _parseConsultationType(json['consultationType']),
      maxPatients: json['maxPatients'] as int? ?? 1,
      currentPatientCount: json['currentPatientCount'] as int? ?? 0,
    );
  }

  static ConsultationType _parseConsultationType(String? type) {
    switch (type?.toLowerCase()) {
      case 'videocall':
        return ConsultationType.videoCall;
      case 'audiocall':
        return ConsultationType.audioCall;
      case 'chat':
        return ConsultationType.chat;
      case 'all':
      default:
        return ConsultationType.all;
    }
  }
}
