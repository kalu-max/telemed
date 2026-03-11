import 'package:flutter/foundation.dart';
import 'doctor_model.dart';
import 'api_client.dart';

class DoctorService extends ChangeNotifier {
  final TeleMedicineApiClient api;

  DoctorService(this.api);

  DoctorProfile? _profile;
  List<Appointment> _appointments = [];

  DoctorProfile? get profile => _profile;
  List<Appointment> get appointments => List.unmodifiable(_appointments);

  Future<void> loadProfile(String doctorId) async {
    final resp = await api.getDoctorProfile(doctorId);
    if (resp.success && resp.data != null) {
      final d = resp.data!;
      _profile = DoctorProfile(
        id: d['id'],
        name: d['name'],
        specialties: List<String>.from(d['specialties'] ?? []),
        bio: d['bio'] ?? '',
        rating: (d['rating'] ?? 0).toDouble(),
        avatarUrl: d['avatarUrl'],
      );
      notifyListeners();
    }
  }

  Future<void> loadAppointments() async {
    final resp = await api.getAppointments();
    if (resp.success && resp.data != null) {
      _appointments = (resp.data as List)
          .map((m) => Appointment.fromMap(m))
          .toList();
      notifyListeners();
    }
  }

  Future<void> acceptAppointment(String id) async {
    await api.updateAppointmentStatus(id, 'confirmed');
    await loadAppointments();
  }

  Future<void> rejectAppointment(String id) async {
    await api.updateAppointmentStatus(id, 'cancelled');
    await loadAppointments();
  }

  Future<void> startAppointment(String id) async {
    await api.updateAppointmentStatus(id, 'started');
    await loadAppointments();
  }

  Future<void> completeAppointment(String id) async {
    await api.updateAppointmentStatus(id, 'completed');
    await loadAppointments();
  }

  // For quick demo/testing
  void seedDemo() {
    _profile = DoctorProfile(id: 'd1', name: 'Dr. Alice', specialties: ['General'], rating: 4.7, avatarUrl: null);
    _appointments = [
      Appointment(id: 'a1', patientName: 'John Doe', startTime: DateTime.now().add(const Duration(minutes: 10))),
      Appointment(id: 'a2', patientName: 'Mary Jane', startTime: DateTime.now().add(const Duration(hours: 1))),
    ];
    notifyListeners();
  }

  /// Fetch list of doctors (patients view) optional spec filter
  Future<List<DoctorProfile>> fetchAvailableDoctors({String? specialization}) async {
    final resp = await api.getAvailableDoctors(specialization: specialization);
    if (resp.success && resp.data != null) {
      return (resp.data as List).map((m) => DoctorProfile.fromJson(m)).toList();
    }
    return [];
  }
}
