import 'package:flutter/foundation.dart';
import '../models/presence_model.dart';
import '../services/presence_service.dart';

/// Provider for managing doctor availability and presence
class PresenceProvider extends ChangeNotifier {
  final PresenceService _presenceService;

  List<DoctorPresence> _availableDoctors = [];
  final Map<String, DoctorPresence> _watchedDoctorPresence = {};
  bool _isConnected = false;
  String? _errorMessage;

  // Getters
  List<DoctorPresence> get availableDoctors => List.unmodifiable(_availableDoctors);
  Map<String, DoctorPresence> get watchedDoctorPresence =>
      Map.unmodifiable(_watchedDoctorPresence);
  bool get isConnected => _isConnected;
  String? get errorMessage => _errorMessage;

  PresenceProvider({required PresenceService presenceService})
      : _presenceService = presenceService {
    _initializeListeners();
  }

  void _initializeListeners() {
    _presenceService.connectionStatusStream.listen((status) {
      _isConnected = status;
      _errorMessage = null;
      notifyListeners();
    });

    _presenceService.availableDoctorsStream.listen((doctors) {
      _availableDoctors = doctors;
      _availableDoctors.sort((a, b) => b.availabilityScore.compareTo(a.availabilityScore));
      _errorMessage = null;
      notifyListeners();
    });

    _presenceService.presenceUpdateStream.listen((presence) {
      if (_watchedDoctorPresence.containsKey(presence.doctorId)) {
        _watchedDoctorPresence[presence.doctorId] = presence;
        // Also update in available doctors list if present
        final index = _availableDoctors.indexWhere((d) => d.doctorId == presence.doctorId);
        if (index != -1) {
          _availableDoctors[index] = presence;
          _availableDoctors.sort((a, b) => b.availabilityScore.compareTo(a.availabilityScore));
        }
        notifyListeners();
      }
    });
  }

  /// Initialize the presence service
  Future<void> initialize() async {
    try {
      await _presenceService.initialize();
    } catch (e) {
      _errorMessage = 'Failed to initialize presence service: $e';
      notifyListeners();
    }
  }

  /// Get available doctors by specialty
  void getAvailableDoctors({String? specialty, int limit = 20}) {
    _presenceService.requestAvailableDoctors(specialty: specialty, limit: limit);
  }

  /// Watch a specific doctor's presence
  void watchDoctor(String doctorId) {
    _presenceService.watchDoctor(doctorId);
  }

  /// Stop watching a doctor
  void unwatchDoctor(String doctorId) {
    _presenceService.unwatchDoctor(doctorId);
    _watchedDoctorPresence.remove(doctorId);
    notifyListeners();
  }

  /// Get doctor presence by ID
  DoctorPresence? getDoctorPresence(String doctorId) {
    return _watchedDoctorPresence[doctorId] ?? 
           _availableDoctors.firstWhere(
             (doc) => doc.doctorId == doctorId,
             orElse: () => DoctorPresence(
               doctorId: doctorId,
               doctorName: '',
               specialty: '',
               status: PresenceStatus.offline,
               consultationType: ConsultationType.all,
               lastSeen: DateTime.now(),
               isVerified: false,
               acceptsEmergency: false,
             ),
           );
  }

  /// Filter doctors by specialty
  List<DoctorPresence> filterBySpecialty(String specialty) {
    return _availableDoctors
        .where((doc) => doc.specialty.toLowerCase().contains(specialty.toLowerCase()))
        .toList();
  }

  /// Filter online doctors
  List<DoctorPresence> getOnlineDoctors() {
    return _availableDoctors.where((doc) => doc.isAvailable).toList();
  }

  /// Filter by consultation type
  List<DoctorPresence> filterByConsultationType(ConsultationType type) {
    return _availableDoctors
        .where((doc) => doc.consultationType == type || doc.consultationType == ConsultationType.all)
        .toList();
  }

  /// Sort by rating (highest first)
  List<DoctorPresence> getSortedByRating() {
    final sorted = List<DoctorPresence>.from(_availableDoctors);
    sorted.sort((a, b) => (b.ratingScore ?? 0).compareTo(a.ratingScore ?? 0));
    return sorted;
  }

  /// Sort by consultation fee (lowest first)
  List<DoctorPresence> getSortedByFee() {
    final sorted = List<DoctorPresence>.from(_availableDoctors);
    sorted.sort((a, b) => (a.consultationFee ?? 9999).compareTo(b.consultationFee ?? 9999));
    return sorted;
  }

  /// Sort by response time (fast first)
  List<DoctorPresence> getSortedByResponseTime() {
    final sorted = List<DoctorPresence>.from(_availableDoctors);
    sorted.sort((a, b) => (a.responseTimeSeconds ?? 9999)
        .compareTo(b.responseTimeSeconds ?? 9999));
    return sorted;
  }

  /// Clear all data
  void clearCache() {
    _availableDoctors.clear();
    _watchedDoctorPresence.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _presenceService.dispose();
    super.dispose();
  }
}
