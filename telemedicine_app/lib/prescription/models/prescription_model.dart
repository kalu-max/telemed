import 'package:hive/hive.dart';

// Note: Hive generation removed - use manual serialization

/// Dosage frequency enumeration
enum DosageFrequency {
  oncDaily,          // Once daily
  twiceDaily,        // Twice daily
  thriceDaily,       // Three times daily
  fourTimesDaily,    // Four times daily
  everyEightHours,   // Every 8 hours
  everySixHours,     // Every 6 hours
  everyFourHours,    // Every 4 hours
  asNeeded,          // As needed (PRN)
  oncWeekly,         // Once weekly
  twiceWeekly,       // Twice weekly
  custom             // Custom frequency
}

/// Medicine unit of measurement
enum MedicineUnit {
  mg,        // Milligrams
  g,         // Grams
  ml,        // Milliliters
  mcg,       // Micrograms
  iu,        // International Units
  units,     // Units
  tablet,    // Tablets
  capsule,   // Capsules
  drops,     // Drops
  inhales    // Inhalations
}

/// Prescription status
enum PrescriptionStatus {
  draft,        // Not yet issued
  active,       // Currently valid
  completed,    // Course completed
  cancelled,    // Cancelled by doctor
  expired       // Validity expired
}

/// Medicine information
@HiveType(typeId: 52)
class Medicine extends HiveObject {
  @HiveField(0)
  final String medicineId;

  @HiveField(1)
  final String medicineName;

  @HiveField(2)
  final String? genericName;

  @HiveField(3)
  final double dosage;

  @HiveField(4)
  final String dosageUnit;

  @HiveField(5)
  final String frequency;

  @HiveField(6)
  final int durationDays;

  @HiveField(7)
  final String? instructions;

  @HiveField(8)
  final List<String>? sideEffects;

  @HiveField(9)
  final List<String>? contraindications;

  @HiveField(10)
  final bool? requiresRefill;

  @HiveField(11)
  final String? manufacturerName;

  @HiveField(12)
  final double? price;

  Medicine({
    required this.medicineId,
    required this.medicineName,
    this.genericName,
    required this.dosage,
    required this.dosageUnit,
    required this.frequency,
    required this.durationDays,
    this.instructions,
    this.sideEffects,
    this.contraindications,
    this.requiresRefill,
    this.manufacturerName,
    this.price,
  });

  Map<String, dynamic> toJson() => {
    'medicineId': medicineId,
    'medicineName': medicineName,
    'genericName': genericName,
    'dosage': dosage,
    'dosageUnit': dosageUnit,
    'frequency': frequency,
    'durationDays': durationDays,
    'instructions': instructions,
    'sideEffects': sideEffects,
    'contraindications': contraindications,
    'requiresRefill': requiresRefill,
    'manufacturerName': manufacturerName,
    'price': price,
  };

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      medicineId: json['medicineId'] as String,
      medicineName: json['medicineName'] as String,
      genericName: json['genericName'] as String?,
      dosage: (json['dosage'] as num?)?.toDouble() ?? 0.0,
      dosageUnit: json['dosageUnit'] as String? ?? 'mg',
      frequency: json['frequency'] as String,
      durationDays: json['durationDays'] as int? ?? 7,
      instructions: json['instructions'] as String?,
      sideEffects: List<String>.from(json['sideEffects'] as List? ?? []),
      contraindications: List<String>.from(json['contraindications'] as List? ?? []),
      requiresRefill: json['requiresRefill'] as bool?,
      manufacturerName: json['manufacturerName'] as String?,
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}

/// Prescription template for doctors
@HiveType(typeId: 53)
class PrescriptionTemplate extends HiveObject {
  @HiveField(0)
  final String templateId;

  @HiveField(1)
  final String doctorId;

  @HiveField(2)
  final String templateName;

  @HiveField(3)
  final String? templateDescription;

  @HiveField(4)
  final List<Medicine> medicines;

  @HiveField(5)
  final String? diagnosis;

  @HiveField(6)
  final String? additionalInstructions;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final bool isPublic;

  PrescriptionTemplate({
    required this.templateId,
    required this.doctorId,
    required this.templateName,
    this.templateDescription,
    required this.medicines,
    this.diagnosis,
    this.additionalInstructions,
    required this.createdAt,
    required this.isPublic,
  });

  Map<String, dynamic> toJson() => {
    'templateId': templateId,
    'doctorId': doctorId,
    'templateName': templateName,
    'templateDescription': templateDescription,
    'medicines': medicines.map((m) => m.toJson()).toList(),
    'diagnosis': diagnosis,
    'additionalInstructions': additionalInstructions,
    'createdAt': createdAt.toIso8601String(),
    'isPublic': isPublic,
  };

  factory PrescriptionTemplate.fromJson(Map<String, dynamic> json) {
    return PrescriptionTemplate(
      templateId: json['templateId'] as String,
      doctorId: json['doctorId'] as String,
      templateName: json['templateName'] as String,
      templateDescription: json['templateDescription'] as String?,
      medicines: (json['medicines'] as List?)
          ?.map((m) => Medicine.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      diagnosis: json['diagnosis'] as String?,
      additionalInstructions: json['additionalInstructions'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isPublic: json['isPublic'] as bool? ?? false,
    );
  }
}

/// Complete prescription document
@HiveType(typeId: 54)
class Prescription extends HiveObject {
  @HiveField(0)
  final String prescriptionId;

  @HiveField(1)
  final String patientId;

  @HiveField(2)
  final String patientName;

  @HiveField(3)
  final String patientEmail;

  @HiveField(4)
  final String patientPhone;

  @HiveField(5)
  final String doctorId;

  @HiveField(6)
  final String doctorName;

  @HiveField(7)
  final String? doctorLicenseNumber;

  @HiveField(8)
  final String consultationId;

  @HiveField(9)
  final DateTime consultationDate;

  @HiveField(10)
  final String? symptoms;

  @HiveField(11)
  final String? diagnosis;

  @HiveField(12)
  final String? clinicalNotes;

  @HiveField(13)
  final List<Medicine> medicines;

  @HiveField(14)
  final String? dietaryInstructions;

  @HiveField(15)
  final String? lifestyleInstructions;

  @HiveField(16)
  final String? followUpInstructions;

  @HiveField(17)
  final DateTime? followUpDate;

  @HiveField(18)
  final int? followUpDaysInterval;

  @HiveField(19)
  final PrescriptionStatus status;

  @HiveField(20)
  final DateTime issuedAt;

  @HiveField(21)
  final DateTime? expiryDate;

  @HiveField(22)
  final String? digitalSignature;

  @HiveField(23)
  final String? prescriptionImageUrl;

  @HiveField(24)
  final String? pdfUrl;

  @HiveField(25)
  final bool isEncrypted;

  @HiveField(26)
  final List<String>? labTests;

  @HiveField(27)
  final String? referralDoctor;

  @HiveField(28)
  final bool patientViewed;

  @HiveField(29)
  final DateTime? createdAt;

  Prescription({
    required this.prescriptionId,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.patientPhone,
    required this.doctorId,
    required this.doctorName,
    this.doctorLicenseNumber,
    required this.consultationId,
    required this.consultationDate,
    this.symptoms,
    this.diagnosis,
    this.clinicalNotes,
    required this.medicines,
    this.dietaryInstructions,
    this.lifestyleInstructions,
    this.followUpInstructions,
    this.followUpDate,
    this.followUpDaysInterval,
    required this.status,
    required this.issuedAt,
    this.expiryDate,
    this.digitalSignature,
    this.prescriptionImageUrl,
    this.pdfUrl,
    required this.isEncrypted,
    this.labTests,
    this.referralDoctor,
    required this.patientViewed,
    this.createdAt,
  });

  /// Check if prescription is still valid
  bool get isValid => status == PrescriptionStatus.active && 
      (expiryDate == null || DateTime.now().isBefore(expiryDate!));

  /// Get days remaining until expiry
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  /// Check if prescription will expire soon (within 7 days)
  bool get expiryWarning => daysUntilExpiry != null && daysUntilExpiry! <= 7 && daysUntilExpiry! > 0;

  /// Calculate total duration of prescription
  int get maxMedicineDuration {
    if (medicines.isEmpty) return 0;
    return medicines.map((m) => m.durationDays).reduce((a, b) => a > b ? a : b);
  }

  /// Get prescription validity period
  Duration get validityPeriod => issuedAt.difference(consultationDate);

  /// Create copy with updated fields
  Prescription copyWith({
    String? prescriptionId,
    String? patientId,
    String? patientName,
    String? patientEmail,
    String? patientPhone,
    String? doctorId,
    String? doctorName,
    String? doctorLicenseNumber,
    String? consultationId,
    DateTime? consultationDate,
    String? symptoms,
    String? diagnosis,
    String? clinicalNotes,
    List<Medicine>? medicines,
    String? dietaryInstructions,
    String? lifestyleInstructions,
    String? followUpInstructions,
    DateTime? followUpDate,
    int? followUpDaysInterval,
    PrescriptionStatus? status,
    DateTime? issuedAt,
    DateTime? expiryDate,
    String? digitalSignature,
    String? prescriptionImageUrl,
    String? pdfUrl,
    bool? isEncrypted,
    List<String>? labTests,
    String? referralDoctor,
    bool? patientViewed,
    DateTime? createdAt,
  }) {
    return Prescription(
      prescriptionId: prescriptionId ?? this.prescriptionId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientEmail: patientEmail ?? this.patientEmail,
      patientPhone: patientPhone ?? this.patientPhone,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      doctorLicenseNumber: doctorLicenseNumber ?? this.doctorLicenseNumber,
      consultationId: consultationId ?? this.consultationId,
      consultationDate: consultationDate ?? this.consultationDate,
      symptoms: symptoms ?? this.symptoms,
      diagnosis: diagnosis ?? this.diagnosis,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      medicines: medicines ?? this.medicines,
      dietaryInstructions: dietaryInstructions ?? this.dietaryInstructions,
      lifestyleInstructions: lifestyleInstructions ?? this.lifestyleInstructions,
      followUpInstructions: followUpInstructions ?? this.followUpInstructions,
      followUpDate: followUpDate ?? this.followUpDate,
      followUpDaysInterval: followUpDaysInterval ?? this.followUpDaysInterval,
      status: status ?? this.status,
      issuedAt: issuedAt ?? this.issuedAt,
      expiryDate: expiryDate ?? this.expiryDate,
      digitalSignature: digitalSignature ?? this.digitalSignature,
      prescriptionImageUrl: prescriptionImageUrl ?? this.prescriptionImageUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      labTests: labTests ?? this.labTests,
      referralDoctor: referralDoctor ?? this.referralDoctor,
      patientViewed: patientViewed ?? this.patientViewed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'prescriptionId': prescriptionId,
    'patientId': patientId,
    'patientName': patientName,
    'patientEmail': patientEmail,
    'patientPhone': patientPhone,
    'doctorId': doctorId,
    'doctorName': doctorName,
    'doctorLicenseNumber': doctorLicenseNumber,
    'consultationId': consultationId,
    'consultationDate': consultationDate.toIso8601String(),
    'symptoms': symptoms,
    'diagnosis': diagnosis,
    'clinicalNotes': clinicalNotes,
    'medicines': medicines.map((m) => m.toJson()).toList(),
    'dietaryInstructions': dietaryInstructions,
    'lifestyleInstructions': lifestyleInstructions,
    'followUpInstructions': followUpInstructions,
    'followUpDate': followUpDate?.toIso8601String(),
    'followUpDaysInterval': followUpDaysInterval,
    'status': status.toString().split('.').last,
    'issuedAt': issuedAt.toIso8601String(),
    'expiryDate': expiryDate?.toIso8601String(),
    'digitalSignature': digitalSignature,
    'prescriptionImageUrl': prescriptionImageUrl,
    'pdfUrl': pdfUrl,
    'isEncrypted': isEncrypted,
    'labTests': labTests,
    'referralDoctor': referralDoctor,
    'patientViewed': patientViewed,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      prescriptionId: json['prescriptionId'] as String,
      patientId: json['patientId'] as String,
      patientName: json['patientName'] as String,
      patientEmail: json['patientEmail'] as String,
      patientPhone: json['patientPhone'] as String,
      doctorId: json['doctorId'] as String,
      doctorName: json['doctorName'] as String,
      doctorLicenseNumber: json['doctorLicenseNumber'] as String?,
      consultationId: json['consultationId'] as String,
      consultationDate: DateTime.parse(json['consultationDate'] as String),
      symptoms: json['symptoms'] as String?,
      diagnosis: json['diagnosis'] as String?,
      clinicalNotes: json['clinicalNotes'] as String?,
      medicines: (json['medicines'] as List?)
          ?.map((m) => Medicine.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      dietaryInstructions: json['dietaryInstructions'] as String?,
      lifestyleInstructions: json['lifestyleInstructions'] as String?,
      followUpInstructions: json['followUpInstructions'] as String?,
      followUpDate: json['followUpDate'] != null
          ? DateTime.parse(json['followUpDate'] as String)
          : null,
      followUpDaysInterval: json['followUpDaysInterval'] as int?,
      status: _parsePrescriptionStatus(json['status']),
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
      digitalSignature: json['digitalSignature'] as String?,
      prescriptionImageUrl: json['prescriptionImageUrl'] as String?,
      pdfUrl: json['pdfUrl'] as String?,
      isEncrypted: json['isEncrypted'] as bool? ?? true,
      labTests: List<String>.from(json['labTests'] as List? ?? []),
      referralDoctor: json['referralDoctor'] as String?,
      patientViewed: json['patientViewed'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  static PrescriptionStatus _parsePrescriptionStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft':
        return PrescriptionStatus.draft;
      case 'active':
        return PrescriptionStatus.active;
      case 'completed':
        return PrescriptionStatus.completed;
      case 'cancelled':
        return PrescriptionStatus.cancelled;
      case 'expired':
      default:
        return PrescriptionStatus.expired;
    }
  }
}

/// Medicine reminder/notification
@HiveType(typeId: 55)
class MedicineReminder extends HiveObject {
  @HiveField(0)
  final String reminderId;

  @HiveField(1)
  final String prescriptionId;

  @HiveField(2)
  final String medicineId;

  @HiveField(3)
  final String medicineName;

  @HiveField(4)
  final List<DateTime> reminderTimes;

  @HiveField(5)
  final bool isActive;

  @HiveField(6)
  final List<DateTime> takenAt;

  @HiveField(7)
  final List<DateTime> missedAt;

  @HiveField(8)
  final DateTime createdAt;

  MedicineReminder({
    required this.reminderId,
    required this.prescriptionId,
    required this.medicineId,
    required this.medicineName,
    required this.reminderTimes,
    required this.isActive,
    required this.takenAt,
    required this.missedAt,
    required this.createdAt,
  });

  /// Calculate adherence percentage
  double get adherencePercentage {
    final total = takenAt.length + missedAt.length;
    if (total == 0) return 0;
    return (takenAt.length / total) * 100;
  }

  /// Get next reminder time
  DateTime? get nextReminder {
    final now = DateTime.now();
    return reminderTimes.firstWhere(
      (time) => time.isAfter(now),
      orElse: () => reminderTimes.isNotEmpty ? reminderTimes.first : now,
    );
  }

  Map<String, dynamic> toJson() => {
    'reminderId': reminderId,
    'prescriptionId': prescriptionId,
    'medicineId': medicineId,
    'medicineName': medicineName,
    'reminderTimes': reminderTimes.map((t) => t.toIso8601String()).toList(),
    'isActive': isActive,
    'takenAt': takenAt.map((t) => t.toIso8601String()).toList(),
    'missedAt': missedAt.map((t) => t.toIso8601String()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory MedicineReminder.fromJson(Map<String, dynamic> json) {
    return MedicineReminder(
      reminderId: json['reminderId'] as String,
      prescriptionId: json['prescriptionId'] as String,
      medicineId: json['medicineId'] as String,
      medicineName: json['medicineName'] as String,
      reminderTimes: (json['reminderTimes'] as List?)
          ?.map((t) => DateTime.parse(t as String))
          .toList() ?? [],
      isActive: json['isActive'] as bool? ?? true,
      takenAt: (json['takenAt'] as List?)
          ?.map((t) => DateTime.parse(t as String))
          .toList() ?? [],
      missedAt: (json['missedAt'] as List?)
          ?.map((t) => DateTime.parse(t as String))
          .toList() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
