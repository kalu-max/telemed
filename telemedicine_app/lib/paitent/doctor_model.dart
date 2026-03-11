
class Availability {
  final String day; // e.g., 'Mon'
  final String start; // '09:00'
  final String end; // '17:00'

  Availability({required this.day, required this.start, required this.end});
}

class DoctorProfile {
  final String id;
  final String name;
  final List<String> specialties;
  final String bio;
  final double rating;
  final String? avatarUrl;
  final double? consultationFee;
  final String? qualification;
  final int? yearsOfExperience;
  final List<Availability> availability;

  DoctorProfile({
    required this.id,
    required this.name,
    this.specialties = const [],
    this.bio = '',
    this.rating = 0.0,
    this.avatarUrl,
    this.consultationFee,
    this.qualification,
    this.yearsOfExperience,
    this.availability = const [],
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    // backend may return either a list of specialties or a single specialization string
    List<String> specs = [];
    if (json['specialties'] != null) {
      specs = (json['specialties'] as List<dynamic>).map((e) => e.toString()).toList();
    } else if (json['specialization'] != null) {
      specs = [json['specialization'].toString()];
    }

    return DoctorProfile(
      id: (json['id'] ?? json['userId'])?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      specialties: specs,
      bio: json['bio']?.toString() ?? '',
      rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 0.0,
      avatarUrl: json['avatarUrl']?.toString(),
      consultationFee: json['consultationFee'] is num ? (json['consultationFee'] as num).toDouble() : null,
      qualification: json['qualification']?.toString(),
      yearsOfExperience: json['yearsOfExperience'] is num ? (json['yearsOfExperience'] as num).toInt() : null,
      availability: const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'specialties': specialties,
        'bio': bio,
        'rating': rating,
        'avatarUrl': avatarUrl,
        'consultationFee': consultationFee,
        'qualification': qualification,
        'yearsOfExperience': yearsOfExperience,
      };
}

enum AppointmentStatus { pending, confirmed, started, completed, rejected }

class Appointment {
  final String id;
  final String patientName;
  final DateTime startTime;
  final AppointmentStatus status;

  Appointment({
    required this.id,
    required this.patientName,
    required this.startTime,
    this.status = AppointmentStatus.pending,
  });

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'] ?? '',
      patientName: map['patientName'] ?? '',
      startTime: map['startTime'] is String
          ? DateTime.parse(map['startTime'])
          : (map['startTime'] ?? DateTime.now()),
      status: _parseStatus(map['status']),
    );
  }

  static AppointmentStatus _parseStatus(dynamic status) {
    if (status is AppointmentStatus) return status;
    if (status is String) {
      switch (status.toLowerCase()) {
        case 'confirmed':
          return AppointmentStatus.confirmed;
        case 'started':
          return AppointmentStatus.started;
        case 'completed':
          return AppointmentStatus.completed;
        case 'rejected':
          return AppointmentStatus.rejected;
        default:
          return AppointmentStatus.pending;
      }
    }
    return AppointmentStatus.pending;
  }
}
