import 'package:flutter/foundation.dart';
import '../models/prescription_model.dart';
import '../services/prescription_service.dart';

/// Provider for managing prescriptions and medicine reminders
class PrescriptionProvider extends ChangeNotifier {
  final PrescriptionService _prescriptionService;

  List<Prescription> _userPrescriptions = [];
  List<Prescription> _activePrescriptions = [];
  final Map<String, List<MedicineReminder>> _prescriptionReminders = {};
  List<PrescriptionTemplate> _templates = [];
  bool _isConnected = false;
  String? _errorMessage;
  bool _isLoading = false;

  // Getters
  List<Prescription> get userPrescriptions => List.unmodifiable(_userPrescriptions);
  List<Prescription> get activePrescriptions => List.unmodifiable(_activePrescriptions);
  Map<String, List<MedicineReminder>> get prescriptionReminders =>
      Map.unmodifiable(_prescriptionReminders);
  List<PrescriptionTemplate> get templates => List.unmodifiable(_templates);
  bool get isConnected => _isConnected;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  PrescriptionProvider({required PrescriptionService prescriptionService})
      : _prescriptionService = prescriptionService {
    _initializeListeners();
  }

  void _initializeListeners() {
    _prescriptionService.connectionStatusStream.listen((status) {
      _isConnected = status;
      _errorMessage = null;
      notifyListeners();
    });

    _prescriptionService.myPrescriptionsStream.listen((prescriptions) {
      _userPrescriptions = prescriptions;
      _updateActivePrescriptions();
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    });

    _prescriptionService.prescriptionUpdateStream.listen((prescription) {
      final index = _userPrescriptions.indexWhere((p) => p.prescriptionId == prescription.prescriptionId);
      if (index != -1) {
        _userPrescriptions[index] = prescription;
      } else {
        _userPrescriptions.add(prescription);
      }
      _updateActivePrescriptions();
      notifyListeners();
    });

    _prescriptionService.medicineReminderStream.listen((reminder) {
      if (!_prescriptionReminders.containsKey(reminder.prescriptionId)) {
        _prescriptionReminders[reminder.prescriptionId] = [];
      }
      final index = _prescriptionReminders[reminder.prescriptionId]!
          .indexWhere((r) => r.reminderId == reminder.reminderId);
      if (index != -1) {
        _prescriptionReminders[reminder.prescriptionId]![index] = reminder;
      } else {
        _prescriptionReminders[reminder.prescriptionId]!.add(reminder);
      }
      notifyListeners();
    });
  }

  /// Initialize the prescription service
  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();
      await _prescriptionService.initialize();
      _templates = _prescriptionService.getTemplates();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to initialize prescription service: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new prescription
  Future<Prescription> createPrescription({
    required String patientId,
    required String patientName,
    required String patientEmail,
    required String patientPhone,
    required String doctorId,
    required String doctorName,
    required String consultationId,
    required DateTime consultationDate,
    String? symptoms,
    String? diagnosis,
    String? clinicalNotes,
    required List<Medicine> medicines,
    String? dietaryInstructions,
    String? lifestyleInstructions,
    String? followUpInstructions,
    DateTime? followUpDate,
    int? followUpDaysInterval,
    List<String>? labTests,
    String? referralDoctor,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final prescription = await _prescriptionService.createPrescription(
        patientId: patientId,
        patientName: patientName,
        patientEmail: patientEmail,
        patientPhone: patientPhone,
        doctorId: doctorId,
        doctorName: doctorName,
        consultationId: consultationId,
        consultationDate: consultationDate,
        symptoms: symptoms,
        diagnosis: diagnosis,
        clinicalNotes: clinicalNotes,
        medicines: medicines,
        dietaryInstructions: dietaryInstructions,
        lifestyleInstructions: lifestyleInstructions,
        followUpInstructions: followUpInstructions,
        followUpDate: followUpDate,
        followUpDaysInterval: followUpDaysInterval,
        labTests: labTests,
        referralDoctor: referralDoctor,
      );

      _errorMessage = null;
      return prescription;
    } catch (e) {
      _errorMessage = 'Failed to create prescription: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update existing prescription
  Future<void> updatePrescription(Prescription prescription) async {
    try {
      await _prescriptionService.updatePrescription(prescription);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update prescription: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Mark prescription as viewed by patient
  Future<void> markPrescriptionAsViewed(String prescriptionId) async {
    try {
      await _prescriptionService.markPrescriptionAsViewed(prescriptionId);
      final index = _userPrescriptions.indexWhere((p) => p.prescriptionId == prescriptionId);
      if (index != -1) {
        _userPrescriptions[index] = _userPrescriptions[index].copyWith(patientViewed: true);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to mark prescription as viewed: $e';
      notifyListeners();
    }
  }

  /// Get prescription by ID
  Prescription? getPrescription(String prescriptionId) {
    try {
      return _prescriptionService.getPrescription(prescriptionId);
    } catch (e) {
      return null;
    }
  }

  /// Get reminders for a prescription
  List<MedicineReminder> getReminders(String prescriptionId) {
    return _prescriptionReminders[prescriptionId] ?? [];
  }

  /// Set medicine reminder
  Future<MedicineReminder> setMedicineReminder({
    required String prescriptionId,
    required String medicineId,
    required String medicineName,
    required List<DateTime> reminderTimes,
  }) async {
    try {
      final reminder = await _prescriptionService.setMedicineReminder(
        prescriptionId: prescriptionId,
        medicineId: medicineId,
        medicineName: medicineName,
        reminderTimes: reminderTimes,
      );
      return reminder;
    } catch (e) {
      _errorMessage = 'Failed to set reminder: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Mark medicine as taken
  Future<void> markMedicineAsTaken(String reminderId) async {
    try {
      await _prescriptionService.markMedicineAsTaken(reminderId);
    } catch (e) {
      _errorMessage = 'Failed to mark medicine as taken: $e';
      notifyListeners();
    }
  }

  /// Create prescription template
  Future<PrescriptionTemplate> createTemplate({
    required String templateName,
    String? templateDescription,
    required List<Medicine> medicines,
    String? diagnosis,
    String? additionalInstructions,
    bool isPublic = false,
  }) async {
    try {
      final template = await _prescriptionService.createTemplate(
        templateName: templateName,
        templateDescription: templateDescription,
        medicines: medicines,
        diagnosis: diagnosis,
        additionalInstructions: additionalInstructions,
        isPublic: isPublic,
      );
      _templates = _prescriptionService.getTemplates();
      notifyListeners();
      return template;
    } catch (e) {
      _errorMessage = 'Failed to create template: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Apply template to create prescription
  Prescription applyTemplate(
    PrescriptionTemplate template, {
    required String patientId,
    required String patientName,
    required String patientEmail,
    required String patientPhone,
    required String consultationId,
    required DateTime consultationDate,
    String? symptoms,
    String? clinicalNotes,
  }) {
    return _prescriptionService.applyTemplate(
      template,
      patientId: patientId,
      patientName: patientName,
      patientEmail: patientEmail,
      patientPhone: patientPhone,
      consultationId: consultationId,
      consultationDate: consultationDate,
      symptoms: symptoms,
      clinicalNotes: clinicalNotes,
    );
  }

  /// Export prescription as PDF
  Future<void> exportPrescriptionPdf(String prescriptionId) async {
    try {
      await _prescriptionService.exportPrescriptionPdf(prescriptionId);
    } catch (e) {
      _errorMessage = 'Failed to export PDF: $e';
      notifyListeners();
    }
  }

  /// Sync with backend
  Future<void> syncWithServer() async {
    try {
      _isLoading = true;
      notifyListeners();
      await _prescriptionService.syncWithServer();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to sync: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get upcoming follow-ups
  List<Prescription> getUpcomingFollowUps() {
    final now = DateTime.now();
    return _userPrescriptions
        .where((p) =>
            p.followUpDate != null &&
            p.followUpDate!.isAfter(now) &&
            p.followUpDate!.isBefore(now.add(const Duration(days: 30))))
        .toList()
      ..sort((a, b) => (a.followUpDate ?? now).compareTo(b.followUpDate ?? now));
  }

  /// Get expiring prescriptions (within 7 days)
  List<Prescription> getExpiringPrescriptions() {
    return _userPrescriptions.where((p) => p.expiryWarning).toList();
  }

  /// Update active prescriptions list
  void _updateActivePrescriptions() {
    _activePrescriptions = _userPrescriptions.where((p) => p.isValid).toList();
  }

  /// Clear all data
  void clearCache() {
    _userPrescriptions.clear();
    _activePrescriptions.clear();
    _prescriptionReminders.clear();
    _templates.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _prescriptionService.dispose();
    super.dispose();
  }
}
