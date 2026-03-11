import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/presence_model.dart';

/// Service for managing doctor presence and availability
class PresenceService {
  final String serverUrl;
  final String userId;
  final String userRole; // 'patient', 'doctor', 'admin'

  late io.Socket _socket;
  
  final StreamController<DoctorPresence> _presenceUpdateController =
      StreamController<DoctorPresence>.broadcast();
  final StreamController<List<DoctorPresence>> _availableDoctorsController =
      StreamController<List<DoctorPresence>>.broadcast();
  final StreamController<PresenceUpdate> _presenceChangeController =
      StreamController<PresenceUpdate>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  final Map<String, DoctorPresence> _cachedPresence = {};
  final List<String> _subscribedDoctorIds = [];
  bool _isConnected = false;

  /// Stream of presence updates for watched doctors
  Stream<DoctorPresence> get presenceUpdateStream =>
      _presenceUpdateController.stream;

  /// Stream of all available doctors
  Stream<List<DoctorPresence>> get availableDoctorsStream =>
      _availableDoctorsController.stream;

  /// Stream of presence status changes
  Stream<PresenceUpdate> get presenceChangeStream =>
      _presenceChangeController.stream;

  /// Stream of connection status
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  /// Get list of currently cached available doctors
  List<DoctorPresence> get cachedAvailableDoctors =>
      _cachedPresence.values.where((doc) => doc.isAvailable).toList()
        ..sort((a, b) => b.availabilityScore.compareTo(a.availabilityScore));

  /// Get connection status
  bool get isConnected => _isConnected;

  PresenceService({
    required this.serverUrl,
    required this.userId,
    required this.userRole,
  });

  /// Initialize presence service and connect to server
  Future<void> initialize() async {
    try {
      _socket = io.io(serverUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'reconnectionAttempts': 999999,
      });

      // Connection events
      _socket.on('connect', (_) {
        _isConnected = true;
        _connectionStatusController.add(true);
        _socket.emit('authenticate', {
          'userId': userId,
          'userRole': userRole,
        });
      });

      _socket.on('presenceUpdate', (data) {
        _handlePresenceUpdate(data);
      });

      _socket.on('presenceChanged', (data) {
        _handlePresenceChange(data);
      });

      _socket.on('availableDoctors', (data) {
        _handleAvailableDoctors(data);
      });

      _socket.on('doctorOnline', (data) {
        _handleDoctorOnline(data);
      });

      _socket.on('doctorOffline', (data) {
        _handleDoctorOffline(data);
      });

      _socket.on('disconnect', (_) {
        _isConnected = false;
        _connectionStatusController.add(false);
      });

      _socket.on('error', (data) {
        // Socket error handled
      });
    } catch (e) {
      _connectionStatusController.addError(e);
    }
  }

  /// Subscribe to a doctor's presence updates
  void watchDoctor(String doctorId) {
    if (!_subscribedDoctorIds.contains(doctorId)) {
      _subscribedDoctorIds.add(doctorId);
      _socket.emit('watchDoctor', {'doctorId': doctorId});
    }
  }

  /// Unsubscribe from doctor's presence updates
  void unwatchDoctor(String doctorId) {
    _subscribedDoctorIds.remove(doctorId);
    _socket.emit('unwatchDoctor', {'doctorId': doctorId});
  }

  /// Request list of available doctors by specialty
  void requestAvailableDoctors({String? specialty, required int limit}) {
    _socket.emit('getAvailableDoctors', {
      'specialty': specialty,
      'limit': limit,
    });
  }

  /// Update doctor's own presence status (for doctors only)
  void updatePresenceStatus(PresenceStatus status) {
    _socket.emit('updatePresenceStatus', {
      'status': status.toString().split('.').last,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Set availability until a specific time (for doctors)
  void setAvailabilityUntil(DateTime untilTime) {
    _socket.emit('setAvailabilityUntil', {
      'availableUntil': untilTime.toIso8601String(),
    });
  }

  /// Update consultation type availability (for doctors)
  void updateConsultationType(ConsultationType type) {
    _socket.emit('updateConsultationType', {
      'consultationType': type.toString().split('.').last,
    });
  }

  /// Get presence for a specific doctor
  DoctorPresence? getDoctorPresence(String doctorId) {
    return _cachedPresence[doctorId];
  }

  /// Get all cached presence data
  Map<String, DoctorPresence> getAllCachedPresence() =>
      Map.unmodifiable(_cachedPresence);

  /// Handle incoming presence update
  void _handlePresenceUpdate(dynamic data) {
    try {
      final presence = DoctorPresence.fromJson(data);
      _cachedPresence[presence.doctorId] = presence;
      _presenceUpdateController.add(presence);
    } catch (e) {
      // Error handled: failed to parse presence update
    }
  }

  /// Handle presence status change
  void _handlePresenceChange(dynamic data) {
    try {
      final update = PresenceUpdate(
        doctorId: data['doctorId'],
        newStatus: _parsePresenceStatus(data['newStatus']),
        timestamp: DateTime.parse(data['timestamp']),
      );
      
      // Update cached presence if exists
      if (_cachedPresence.containsKey(update.doctorId)) {
        final presence = _cachedPresence[update.doctorId]!;
        _cachedPresence[update.doctorId] = presence.copyWith(
          status: update.newStatus,
          lastSeen: update.timestamp,
        );
      }
      
      _presenceChangeController.add(update);
    } catch (e) {
      // Error handled: failed to parse presence change
    }
  }

  /// Handle available doctors list
  void _handleAvailableDoctors(dynamic data) {
    try {
      final List<DoctorPresence> doctors = (data as List)
          .map((doc) => DoctorPresence.fromJson(doc))
          .toList();
      
      // Update cache
      for (var doc in doctors) {
        _cachedPresence[doc.doctorId] = doc;
      }
      
      _availableDoctorsController.add(doctors);
    } catch (e) {
      // Error handled: failed to parse available doctors
    }
  }

  /// Handle doctor coming online
  void _handleDoctorOnline(dynamic data) {
    try {
      final presence = DoctorPresence.fromJson(data);
      _cachedPresence[presence.doctorId] = presence;
      _presenceUpdateController.add(presence);
    } catch (e) {
      // Error handled: failed to parse doctor online
    }
  }

  /// Handle doctor going offline
  void _handleDoctorOffline(dynamic data) {
    try {
      final doctorId = data['doctorId'];
      final offlinePresence = _cachedPresence[doctorId]?.copyWith(
        status: PresenceStatus.offline,
        lastSeen: DateTime.now(),
      );
      
      if (offlinePresence != null) {
        _cachedPresence[doctorId] = offlinePresence;
        _presenceUpdateController.add(offlinePresence);
      }
    } catch (e) {
      // Error handled: failed to parse doctor offline
    }
  }

  static PresenceStatus _parsePresenceStatus(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return PresenceStatus.online;
      case 'busy':
        return PresenceStatus.busy;
      case 'away':
        return PresenceStatus.away;
      case 'donotdisturb':
        return PresenceStatus.doNotDisturb;
      default:
        return PresenceStatus.offline;
    }
  }

  /// Clear all cached presence data
  void clearCache() {
    _cachedPresence.clear();
  }

  /// Dispose resources
  void dispose() {
    _presenceUpdateController.close();
    _availableDoctorsController.close();
    _presenceChangeController.close();
    _connectionStatusController.close();
    _socket.disconnect();
  }
}
