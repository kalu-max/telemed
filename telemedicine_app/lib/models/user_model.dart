/// User Model
/// Represents a user in the system (both patient and doctor)
library;

class User {
  final String id;
  final String name;
  final String email;
  final String role; // 'patient' or 'doctor'
  final String? profileImageUrl;
  final String? phoneNumber;
  final String? bio;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profileImageUrl,
    this.phoneNumber,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'patient',
      profileImageUrl: json['profileImageUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      bio: json['bio'] as String?,
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
    'name': name,
    'email': email,
    'role': role,
    'profileImageUrl': profileImageUrl,
    'phoneNumber': phoneNumber,
    'bio': bio,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? profileImageUrl,
    String? phoneNumber,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
    User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
}

/// Doctor Model (extends User)
class Doctor extends User {
  final List<String> specialties;
  final double rating;
  final int reviewCount;
  final List<String> availableHours;
  final double consultationFee;

  Doctor({
    required super.id,
    required super.name,
    required super.email,
    required super.role,
    super.profileImageUrl,
    super.phoneNumber,
    super.bio,
    required super.createdAt,
    required super.updatedAt,
    required this.specialties,
    required this.rating,
    required this.reviewCount,
    required this.availableHours,
    required this.consultationFee,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'doctor',
      profileImageUrl: json['profileImageUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      bio: json['bio'] as String?,
      createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'] as String) 
        : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
        ? DateTime.parse(json['updatedAt'] as String) 
        : DateTime.now(),
      specialties: List<String>.from(json['specialties'] as List? ?? []),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      availableHours: List<String>.from(json['availableHours'] as List? ?? []),
      consultationFee: (json['consultationFee'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'specialties': specialties,
    'rating': rating,
    'reviewCount': reviewCount,
    'availableHours': availableHours,
    'consultationFee': consultationFee,
  };
}
