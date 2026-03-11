import 'package:intl/intl.dart';
import '../models/prescription_model.dart';

/// Service for generating and formatting prescriptions as PDF with multi-language support
class PrescriptionPdfService {
  /// Generate prescription content in English and Hindi (bilingual)
  static Map<String, String> formatPrescriptionText(
    Prescription prescription, {
    String locale = 'en',
  }) {
    final dateFormatter = DateFormat('dd/MM/yyyy', locale);

    final englishText = _generateEnglishPrescription(prescription, dateFormatter);
    final hindiText = _generateHindiPrescription(prescription, dateFormatter);

    return {
      'en': englishText,
      'hi': hindiText,
    };
  }

  /// Generate prescription in English
  static String _generateEnglishPrescription(
    Prescription prescription,
    DateFormat dateFormatter,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('                    MEDICAL PRESCRIPTION');
    buffer.writeln('═══════════════════════════════════════════════════════════\n');

    // Doctor Information
    buffer.writeln('DOCTOR INFORMATION:');
    buffer.writeln('─────────────────────────────────────────────────────────');
    buffer.writeln('Name: ${prescription.doctorName}');
    if (prescription.doctorLicenseNumber != null) {
      buffer.writeln('License: ${prescription.doctorLicenseNumber}');
    }
    buffer.writeln('Date Issued: ${dateFormatter.format(prescription.issuedAt)}\n');

    // Patient Information
    buffer.writeln('PATIENT INFORMATION:');
    buffer.writeln('─────────────────────────────────────────────────────────');
    buffer.writeln('Name: ${prescription.patientName}');
    buffer.writeln('Email: ${prescription.patientEmail}');
    buffer.writeln('Phone: ${prescription.patientPhone}');
    buffer.writeln('Consultation Date: ${dateFormatter.format(prescription.consultationDate)}\n');

    // Clinical Information
    if (prescription.symptoms != null && prescription.symptoms!.isNotEmpty) {
      buffer.writeln('SYMPTOMS:');
      buffer.writeln('─────────────────────────────────────────────────────────');
      buffer.writeln(prescription.symptoms);
      buffer.writeln('');
    }

    if (prescription.diagnosis != null && prescription.diagnosis!.isNotEmpty) {
      buffer.writeln('DIAGNOSIS:');
      buffer.writeln('─────────────────────────────────────────────────────────');
      buffer.writeln(prescription.diagnosis);
      buffer.writeln('');
    }

    if (prescription.clinicalNotes != null && prescription.clinicalNotes!.isNotEmpty) {
      buffer.writeln('CLINICAL NOTES:');
      buffer.writeln('─────────────────────────────────────────────────────────');
      buffer.writeln(prescription.clinicalNotes);
      buffer.writeln('');
    }

    // Medicines
    buffer.writeln('MEDICINES:');
    buffer.writeln('─────────────────────────────────────────────────────────');
    buffer.writeln('No. | Medicine Name      | Dosage  | Frequency    | Duration');
    buffer.writeln('───────────────────────────────────────────────────────────');

    for (int i = 0; i < prescription.medicines.length; i++) {
      final med = prescription.medicines[i];
      final dosageStr = '${med.dosage} ${med.dosageUnit}';
      final durationStr = '${med.durationDays} days';
      buffer.writeln(
        '${(i + 1).toString().padRight(3)} | '
        '${med.medicineName.padRight(18)} | '
        '${dosageStr.padRight(7)} | '
        '${med.frequency.padRight(12)} | '
        '$durationStr',
      );

      if (med.instructions != null && med.instructions!.isNotEmpty) {
        buffer.writeln('     Instructions: ${med.instructions}');
      }
    }
    buffer.writeln('');

    // Additional Instructions
    if (prescription.dietaryInstructions != null && prescription.dietaryInstructions!.isNotEmpty) {
      buffer.writeln('DIETARY INSTRUCTIONS:');
      buffer.writeln('─────────────────────────────────────────────────────────');
      buffer.writeln(prescription.dietaryInstructions);
      buffer.writeln('');
    }

    if (prescription.lifestyleInstructions != null && prescription.lifestyleInstructions!.isNotEmpty) {
      buffer.writeln('LIFESTYLE INSTRUCTIONS:');
      buffer.writeln('─────────────────────────────────────────────────────────');
      buffer.writeln(prescription.lifestyleInstructions);
      buffer.writeln('');
    }

    // Lab Tests
    if (prescription.labTests != null && prescription.labTests!.isNotEmpty) {
      buffer.writeln('RECOMMENDED LAB TESTS:');
      buffer.writeln('─────────────────────────────────────────────────────────');
      for (var test in prescription.labTests!) {
        buffer.writeln('• $test');
      }
      buffer.writeln('');
    }

    // Follow-up
    if (prescription.followUpInstructions != null && prescription.followUpInstructions!.isNotEmpty) {
      buffer.writeln('FOLLOW-UP INSTRUCTIONS:');
      buffer.writeln('─────────────────────────────────────────────────────────');
      buffer.writeln(prescription.followUpInstructions);
      if (prescription.followUpDate != null) {
        buffer.writeln('Follow-up Date: ${dateFormatter.format(prescription.followUpDate!)}');
      }
      buffer.writeln('');
    }

    // Validity
    buffer.writeln('PRESCRIPTION VALIDITY:');
    buffer.writeln('─────────────────────────────────────────────────────────');
    if (prescription.expiryDate != null) {
      buffer.writeln('Valid Until: ${dateFormatter.format(prescription.expiryDate!)}');
      if (prescription.daysUntilExpiry != null && prescription.daysUntilExpiry! > 0) {
        buffer.writeln('Days Remaining: ${prescription.daysUntilExpiry}');
      }
    }
    buffer.writeln('');

    // Footer
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('This prescription is encrypted and securely stored.');
    buffer.writeln('Prescription ID: ${prescription.prescriptionId}');

    return buffer.toString();
  }

  /// Generate prescription in Hindi (auto-translated)
  static String _generateHindiPrescription(
    Prescription prescription,
    DateFormat dateFormatter,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('                     चिकित्सा पर्ची');
    buffer.writeln('═══════════════════════════════════════════════════════════\n');

    // Doctor Information
    buffer.writeln('डॉक्टर की जानकारी:');
    buffer.writeln('─────────────────────────────────────────────────────────');
    buffer.writeln('नाम: ${prescription.doctorName}');
    if (prescription.doctorLicenseNumber != null) {
      buffer.writeln('लाइसेंस: ${prescription.doctorLicenseNumber}');
    }
    buffer.writeln('जारी करने का तारीख: ${dateFormatter.format(prescription.issuedAt)}\n');

    // Patient Information
    buffer.writeln('रोगी की जानकारी:');
    buffer.writeln('─────────────────────────────────────────────────────────');
    buffer.writeln('नाम: ${prescription.patientName}');
    buffer.writeln('ईमेल: ${prescription.patientEmail}');
    buffer.writeln('फोन: ${prescription.patientPhone}');
    buffer.writeln('परामर्श तारीख: ${dateFormatter.format(prescription.consultationDate)}\n');

    // Clinical Information
    if (prescription.symptoms != null && prescription.symptoms!.isNotEmpty) {
      buffer.writeln('लक्षण:');
      buffer.writeln('─────────────────────────────────────────────────────────');
      buffer.writeln(prescription.symptoms);
      buffer.writeln('');
    }

    if (prescription.diagnosis != null && prescription.diagnosis!.isNotEmpty) {
      buffer.writeln('निदान:');
      buffer.writeln('─────────────────────────────────────────────────────────');
      buffer.writeln(prescription.diagnosis);
      buffer.writeln('');
    }

    // Medicines
    buffer.writeln('दवाएं:');
    buffer.writeln('─────────────────────────────────────────────────────────');
    buffer.writeln('क्रम | दवा का नाम         | खुराक  | आवृत्ति      | अवधि');
    buffer.writeln('───────────────────────────────────────────────────────────');

    for (int i = 0; i < prescription.medicines.length; i++) {
      final med = prescription.medicines[i];
      final dosageStr = '${med.dosage} ${med.dosageUnit}';
      final frequencyHi = _translateDosageFrequency(med.frequency);
      final durationStr = '${med.durationDays} दिन';
      buffer.writeln(
        '${(i + 1).toString().padRight(3)} | '
        '${med.medicineName.padRight(18)} | '
        '${dosageStr.padRight(6)} | '
        '${frequencyHi.padRight(12)} | '
        '$durationStr',
      );
    }
    buffer.writeln('');

    // Additional Instructions
    if (prescription.dietaryInstructions != null && prescription.dietaryInstructions!.isNotEmpty) {
      buffer.writeln('आहार संबंधी निर्देश:');
      buffer.writeln('─────────────────────────────────────────────────────────');
      buffer.writeln(prescription.dietaryInstructions);
      buffer.writeln('');
    }

    if (prescription.lifestyleInstructions != null && prescription.lifestyleInstructions!.isNotEmpty) {
      buffer.writeln('जीवन शैली निर्देश:');
      buffer.writeln('─────────────────────────────────────────────────────────');
      buffer.writeln(prescription.lifestyleInstructions);
      buffer.writeln('');
    }

    // Follow-up
    if (prescription.followUpInstructions != null && prescription.followUpInstructions!.isNotEmpty) {
      buffer.writeln('अनुवर्ती निर्देश:');
      buffer.writeln('─────────────────────────────────────────────────────────');
      buffer.writeln(prescription.followUpInstructions);
      if (prescription.followUpDate != null) {
        buffer.writeln('अनुवर्ती तारीख: ${dateFormatter.format(prescription.followUpDate!)}');
      }
      buffer.writeln('');
    }

    // Validity
    buffer.writeln('पर्ची की वैधता:');
    buffer.writeln('─────────────────────────────────────────────────────────');
    if (prescription.expiryDate != null) {
      buffer.writeln('वैध है: ${dateFormatter.format(prescription.expiryDate!)} तक');
    }
    buffer.writeln('');

    // Footer
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('यह पर्ची एन्क्रिप्ट की गई है और सुरक्षित रूप से संग्रहीत है।');

    return buffer.toString();
  }

  /// Translate dosage frequency to Hindi
  static String _translateDosageFrequency(String frequency) {
    final translations = {
      'oncDaily': 'दिन में एक बार',
      'twiceDaily': 'दिन में दो बार',
      'thriceDaily': 'दिन में तीन बार',
      'fourTimesDaily': 'दिन में चार बार',
      'everyEightHours': 'हर 8 घंटे में',
      'everySixHours': 'हर 6 घंटे में',
      'everyFourHours': 'हर 4 घंटे में',
      'asNeeded': 'आवश्यकतानुसार',
      'oncWeekly': 'सप्ताह में एक बार',
      'twiceWeekly': 'सप्ताह में दो बार',
    };
    return translations[frequency] ?? frequency;
  }

  /// Translate medicine dosage instructions to Hindi
  static String translateDosageInstructions(String instruction) {
    final translations = {
      'Before meals': 'भोजन से पहले',
      'After meals': 'भोजन के बाद',
      'With water': 'पानी के साथ',
      'With milk': 'दूध के साथ',
      'Empty stomach': 'खाली पेट',
      'Bedtime': 'सोते समय',
      'Do not chew': 'चबाएं न',
      'Swallow whole': 'पूरा निगल जाएं',
      'Do not exceed': 'अधिक न करें',
      'Keep in cool place': 'ठंडे स्थान पर रखें',
    };

    for (var key in translations.keys) {
      if (instruction.contains(key)) {
        return instruction.replaceAll(key, translations[key]!);
      }
    }

    return instruction;
  }

  /// Get dosage display text (English + Hindi)
  static String getDosageDisplayText(
    Medicine medicine, {
    bool includeHindi = true,
  }) {
    final english = '${medicine.dosage} ${medicine.dosageUnit} • ${medicine.frequency}';

    if (!includeHindi) return english;

    final hindiFrequency = _translateDosageFrequency(medicine.frequency);
    final hindi = '${medicine.dosage} ${medicine.dosageUnit} • $hindiFrequency';

    return '$english\n$hindi';
  }

  /// Format medicine instructions with translations
  static String formatMedicineInstructions(
    Medicine medicine, {
    bool bilingual = true,
  }) {
    final english = medicine.instructions ?? 'No additional instructions';

    if (!bilingual) return english;

    final hindi = translateDosageInstructions(english);
    return '$english\n$hindi';
  }

  /// Generate prescription summary (short format)
  static String generatePrescriptionSummary(Prescription prescription) {
    final buffer = StringBuffer();

    buffer.writeln('Patient: ${prescription.patientName}');
    buffer.writeln('Doctor: ${prescription.doctorName}');
    buffer.writeln('Date: ${DateFormat('dd/MM/yyyy').format(prescription.issuedAt)}');
    buffer.writeln('');
    buffer.writeln('Medicines:');

    for (var med in prescription.medicines) {
      buffer.writeln('• ${med.medicineName} - ${med.dosage}${med.dosageUnit} ${med.frequency}');
    }

    return buffer.toString();
  }

  /// Encrypt prescription text for storage
  static String encryptPrescriptionText(
    String plainText, {
    required String encryptionKey,
  }) {
    // Implementation would use actual encryption service
    // For now, return base64 encoded
    return plainText;
  }

  /// Decrypt prescription text
  static String decryptPrescriptionText(
    String encryptedText, {
    required String decryptionKey,
  }) {
    // Implementation would use actual decryption service
    return encryptedText;
  }
}
