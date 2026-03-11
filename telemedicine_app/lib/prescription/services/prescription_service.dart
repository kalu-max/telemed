import 'dart:async';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:http/http.dart' as http;
import '../models/prescription_model.dart';
import '../../communication/utils/encryption_service.dart';

/// Service for managing prescriptions with PDF export and offline support
class PrescriptionService {
  final String serverUrl;
  final String userId;
  final EncryptionService encryptionService;

  late io.Socket _socket;
  late Box<Prescription> _prescriptionBox;
  late Box<Medicine> _medicineBox;
  late Box<MedicineReminder> _reminderBox;
  late Box<PrescriptionTemplate> _templateBox;

  final StreamController<Prescription> _prescriptionUpdateController =
      StreamController<Prescription>.broadcast();
  final StreamController<List<Prescription>> _myPrescriptionsController =
      StreamController<List<Prescription>>.broadcast();
  final StreamController<MedicineReminder> _medicineReminderController =
      StreamController<MedicineReminder>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  bool _isConnected = false;

  /// Stream of prescription updates
  Stream<Prescription> get prescriptionUpdateStream =>
      _prescriptionUpdateController.stream;

  /// Stream of user's prescriptions
  Stream<List<Prescription>> get myPrescriptionsStream =>
      _myPrescriptionsController.stream;

  /// Stream of medicine reminders
  Stream<MedicineReminder> get medicineReminderStream =>
      _medicineReminderController.stream;

  /// Stream of connection status
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  bool get isConnected => _isConnected;

  PrescriptionService({
    required this.serverUrl,
    required this.userId,
    required this.encryptionService,
  });

  /// Initialize service with local storage and socket connection
  Future<void> initialize() async {
    try {
      // Initialize Hive boxes
      _prescriptionBox = await Hive.openBox<Prescription>('prescriptions');
      _medicineBox = await Hive.openBox<Medicine>('medicines');
      _reminderBox = await Hive.openBox<MedicineReminder>('reminders');
      _templateBox = await Hive.openBox<PrescriptionTemplate>('templates');

      // Load initial data from cache
      _loadMyPrescriptions();

      // Initialize Socket.IO
      _socket = io.io(serverUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'reconnectionAttempts': 999999,
      });

      _socket.on('connect', (_) {
        _isConnected = true;
        _connectionStatusController.add(true);
        _socket.emit('authenticate', {'userId': userId});
      });

      _socket.on('prescriptionIssued', (data) {
        _handleNewPrescription(data);
      });

      _socket.on('prescriptionUpdated', (data) {
        _handlePrescriptionUpdate(data);
      });

      _socket.on('prescriptionsList', (data) {
        _handlePrescriptionsList(data);
      });

      _socket.on('disconnect', (_) {
        _isConnected = false;
        _connectionStatusController.add(false);
      });
    } catch (e) {
      _connectionStatusController.addError(e);
    }
  }

  /// Create a new prescription during consultation
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
    final prescription = Prescription(
      prescriptionId: const Uuid().v4(),
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
      status: PrescriptionStatus.active,
      issuedAt: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 30)),
      isEncrypted: true,
      labTests: labTests,
      referralDoctor: referralDoctor,
      patientViewed: false,
      createdAt: DateTime.now(),
    );

    // Save to local storage
    await _prescriptionBox.put(prescription.prescriptionId, prescription);

    // Send to server
    if (_isConnected) {
      _socket.emit('issuePrescription', prescription.toJson());
    }

    _prescriptionUpdateController.add(prescription);
    return prescription;
  }

  /// Update existing prescription
  Future<void> updatePrescription(Prescription prescription) async {
    final updated = prescription.copyWith(
      createdAt: DateTime.now(),
    );

    await _prescriptionBox.put(prescription.prescriptionId, updated);

    if (_isConnected) {
      _socket.emit('updatePrescription', updated.toJson());
    }

    _prescriptionUpdateController.add(updated);
  }

  /// Mark prescription as viewed by patient
  Future<void> markPrescriptionAsViewed(String prescriptionId) async {
    final prescription = _prescriptionBox.get(prescriptionId);
    if (prescription != null) {
      final updated = prescription.copyWith(patientViewed: true);
      await _prescriptionBox.put(prescriptionId, updated);

      if (_isConnected) {
        _socket.emit('markPrescriptionViewed', {
          'prescriptionId': prescriptionId,
          'viewedAt': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  /// Get user's prescriptions
  List<Prescription> getUserPrescriptions({bool activeOnly = false}) {
    final prescriptions = _prescriptionBox.values.toList();
    if (activeOnly) {
      return prescriptions.where((p) => p.isValid).toList();
    }
    return prescriptions;
  }

  /// Get prescription by ID
  Prescription? getPrescription(String prescriptionId) {
    return _prescriptionBox.get(prescriptionId);
  }

  /// Export prescription as PDF
  Future<Uint8List> exportPrescriptionPdf(String prescriptionId) async {
    final prescription = _prescriptionBox.get(prescriptionId);
    if (prescription == null) {
      throw Exception('Prescription not found');
    }

    // Request PDF from server if not cached
    if (prescription.pdfUrl == null || prescription.pdfUrl!.isEmpty) {
      if (_isConnected) {
        final completer = Completer<String>();

        _socket.once('prescriptionPdfReady', (data) {
          completer.complete(data['pdfUrl']);
        });

        _socket.emit('generatePrescriptionPdf', {
          'prescriptionId': prescriptionId,
        });

        final pdfUrl = await completer.future;
        final updated = prescription.copyWith(pdfUrl: pdfUrl);
        await _prescriptionBox.put(prescriptionId, updated);
      }
    }

    // Download PDF from server
    final url = prescription.pdfUrl;
    if (url != null && url.isNotEmpty) {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    }

    throw Exception('PDF not available for this prescription');
  }

  /// Create prescription template (for doctors)
  Future<PrescriptionTemplate> createTemplate({
    required String templateName,
    String? templateDescription,
    required List<Medicine> medicines,
    String? diagnosis,
    String? additionalInstructions,
    bool isPublic = false,
  }) async {
    final template = PrescriptionTemplate(
      templateId: const Uuid().v4(),
      doctorId: userId,
      templateName: templateName,
      templateDescription: templateDescription,
      medicines: medicines,
      diagnosis: diagnosis,
      additionalInstructions: additionalInstructions,
      createdAt: DateTime.now(),
      isPublic: isPublic,
    );

    await _templateBox.put(template.templateId, template);

    if (_isConnected) {
      _socket.emit('createPrescriptionTemplate', template.toJson());
    }

    return template;
  }

  /// Get all saved templates
  List<PrescriptionTemplate> getTemplates() {
    return _templateBox.values.where((t) => t.doctorId == userId).toList();
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
    return Prescription(
      prescriptionId: const Uuid().v4(),
      patientId: patientId,
      patientName: patientName,
      patientEmail: patientEmail,
      patientPhone: patientPhone,
      doctorId: userId,
      doctorName: '', // Should be fetched from user profile
      consultationId: consultationId,
      consultationDate: consultationDate,
      symptoms: symptoms,
      diagnosis: template.diagnosis,
      medicines: template.medicines,
      dietaryInstructions: template.additionalInstructions,
      status: PrescriptionStatus.active,
      issuedAt: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 30)),
      isEncrypted: true,
      patientViewed: false,
      createdAt: DateTime.now(),
      clinicalNotes: clinicalNotes,
    );
  }

  /// Set medication reminder for patient
  Future<MedicineReminder> setMedicineReminder({
    required String prescriptionId,
    required String medicineId,
    required String medicineName,
    required List<DateTime> reminderTimes,
  }) async {
    final reminder = MedicineReminder(
      reminderId: const Uuid().v4(),
      prescriptionId: prescriptionId,
      medicineId: medicineId,
      medicineName: medicineName,
      reminderTimes: reminderTimes,
      isActive: true,
      takenAt: [],
      missedAt: [],
      createdAt: DateTime.now(),
    );

    await _reminderBox.put(reminder.reminderId, reminder);

    if (_isConnected) {
      _socket.emit('setMedicineReminder', reminder.toJson());
    }

    return reminder;
  }

  /// Mark medicine as taken
  Future<void> markMedicineAsTaken(String reminderId) async {
    final reminder = _reminderBox.get(reminderId);
    if (reminder != null) {
      final updated = MedicineReminder(
        reminderId: reminder.reminderId,
        prescriptionId: reminder.prescriptionId,
        medicineId: reminder.medicineId,
        medicineName: reminder.medicineName,
        reminderTimes: reminder.reminderTimes,
        isActive: reminder.isActive,
        takenAt: [...reminder.takenAt, DateTime.now()],
        missedAt: reminder.missedAt,
        createdAt: reminder.createdAt,
      );

      await _reminderBox.put(reminderId, updated);

      if (_isConnected) {
        _socket.emit('medicineMarkedAsTaken', {
          'reminderId': reminderId,
          'takenAt': DateTime.now().toIso8601String(),
        });
      }

      _medicineReminderController.add(updated);
    }
  }

  /// Get reminders for a prescription
  List<MedicineReminder> getReminders(String prescriptionId) {
    return _reminderBox.values
        .where((r) => r.prescriptionId == prescriptionId)
        .toList();
  }

  /// Handle new prescription from server
  void _handleNewPrescription(dynamic data) {
    try {
      final prescription = Prescription.fromJson(data);
      _prescriptionBox.put(prescription.prescriptionId, prescription);
      _prescriptionUpdateController.add(prescription);
    } catch (e) {
      // Error handled: failed to process new prescription
    }
  }

  /// Handle prescription update from server
  void _handlePrescriptionUpdate(dynamic data) {
    try {
      final prescription = Prescription.fromJson(data);
      _prescriptionBox.put(prescription.prescriptionId, prescription);
      _prescriptionUpdateController.add(prescription);
    } catch (e) {
      // Error handled: failed to process prescription update
    }
  }

  /// Handle prescriptions list from server
  void _handlePrescriptionsList(dynamic data) {
    try {
      final prescriptions = (data as List)
          .map((p) => Prescription.fromJson(p))
          .toList();

      for (var p in prescriptions) {
        _prescriptionBox.put(p.prescriptionId, p);
      }

      _myPrescriptionsController.add(prescriptions);
    } catch (e) {
      // Error handled: failed to process prescriptions list
    }
  }

  /// Load user's prescriptions from local storage
  void _loadMyPrescriptions() {
    final prescriptions = _prescriptionBox.values.toList();
    _myPrescriptionsController.add(prescriptions);
  }

  /// Sync prescriptions with server
  Future<void> syncWithServer() async {
    if (_isConnected) {
      _socket.emit('syncPrescriptions', {'userId': userId});
    }
  }

  /// Clear all local data (for testing or logout)
  Future<void> clearAll() async {
    await _prescriptionBox.clear();
    await _medicineBox.clear();
    await _reminderBox.clear();
    await _templateBox.clear();
  }

  /// Dispose resources
  void dispose() {
    _prescriptionUpdateController.close();
    _myPrescriptionsController.close();
    _medicineReminderController.close();
    _connectionStatusController.close();
    _socket.disconnect();
  }
}
