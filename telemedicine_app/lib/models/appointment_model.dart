/// Appointment Model
/// Represents a scheduled consultation
library;

enum AppointmentStatus {
  scheduled,
  confirmed,
  ongoing,
  completed,
  cancelled,
  noShow,
}

class Appointment {
  final String id;
  final String patientId;
  final String doctorId;
  final String patientName;
  final String doctorName;
  final String specialty;
  final DateTime scheduledTime;
  final Duration duration;
  final AppointmentStatus status;
  final String? notes;
  final String? prescription;
  final double? consultationFee;
  final DateTime createdAt;
  final DateTime updatedAt;

  Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.patientName,
    required this.doctorName,
    required this.specialty,
    required this.scheduledTime,
    required this.duration,
    required this.status,
    this.notes,
    this.prescription,
    this.consultationFee,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      doctorId: json['doctorId'] as String? ?? '',
      patientName: json['patientName'] as String? ?? '',
      doctorName: json['doctorName'] as String? ?? '',
      specialty: json['specialty'] as String? ?? '',
      scheduledTime: json['scheduledTime'] != null 
        ? DateTime.parse(json['scheduledTime'] as String) 
        : DateTime.now(),
      duration: json['duration'] != null 
        ? Duration(minutes: json['duration'] as int) 
        : const Duration(minutes: 30),
      status: AppointmentStatus.values[json['status'] as int? ?? 0],
      notes: json['notes'] as String?,
      prescription: json['prescription'] as String?,
      consultationFee: (json['consultationFee'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'] as String) 
        : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
        ? DateTime.parse(json['updatedAt'] as String) 
        : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'doctorId': doctorId,
    'patientName': patientName,
    'doctorName': doctorName,
    'specialty': specialty,
    'scheduledTime': scheduledTime.toIso8601String(),
    'duration': duration.inMinutes,
    'status': status.index,
    'notes': notes,
    'prescription': prescription,
    'consultationFee': consultationFee,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Appointment copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? patientName,
    String? doctorName,
    String? specialty,
    DateTime? scheduledTime,
    Duration? duration,
    AppointmentStatus? status,
    String? notes,
    String? prescription,
    double? consultationFee,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
    Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      patientName: patientName ?? this.patientName,
      doctorName: doctorName ?? this.doctorName,
      specialty: specialty ?? this.specialty,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      prescription: prescription ?? this.prescription,
      consultationFee: consultationFee ?? this.consultationFee,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
}
