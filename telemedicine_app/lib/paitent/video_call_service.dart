import 'package:flutter/foundation.dart';
import 'dart:async';
import '../communication/services/video_calling_service.dart' as comm;
import '../communication/services/bandwidth_optimization_service.dart';
import '../communication/models/call_model.dart' as call_model;
import '../config/app_config.dart';

enum CallStatus { idle, connecting, connected, disconnected, failed }

/// Delegates to the real [comm.VideoCallingService] for WebRTC calls.
class VideoCallService extends ChangeNotifier {
  late final comm.VideoCallingService _realService;
  StreamSubscription? _stateSub;

  CallStatus _callStatus = CallStatus.idle;
  bool _isAudioEnabled = true;
  bool _isVideoEnabled = true;
  bool _isSpeakerEnabled = true;
  String? _remoteUserName;
  String? _remoteUserAvatar;
  Duration _callDuration = Duration.zero;

  CallStatus get callStatus => _callStatus;
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  String? get remoteUserName => _remoteUserName;
  String? get remoteUserAvatar => _remoteUserAvatar;
  Duration get callDuration => _callDuration;

  /// Expose the underlying service so the UI can access renderers.
  comm.VideoCallingService get realService => _realService;

  VideoCallService() {
    _realService = comm.VideoCallingService(
      signalingServerUrl: AppConfig.apiBaseUrl,
      userId: 'patient-${DateTime.now().millisecondsSinceEpoch}',
      userName: 'Patient',
      bandwidthService: BandwidthOptimizationService(),
    );
    _realService.initialize();
    _listenToState();
  }

  void _listenToState() {
    _stateSub = _realService.callStateStream.listen((session) {
      switch (session.status) {
        case call_model.CallStatus.initiating:
        case call_model.CallStatus.ringing:
        case call_model.CallStatus.connecting:
          _callStatus = CallStatus.connecting;
        case call_model.CallStatus.accepted:
        case call_model.CallStatus.connected:
          _callStatus = CallStatus.connected;
        case call_model.CallStatus.disconnecting:
        case call_model.CallStatus.disconnected:
        case call_model.CallStatus.ended:
          _callStatus = CallStatus.disconnected;
        case call_model.CallStatus.rejected:
        case call_model.CallStatus.missed:
        case call_model.CallStatus.failed:
          _callStatus = CallStatus.failed;
      }
      notifyListeners();
    });
  }

  Future<bool> initiateCall(String remoteUserId, String remoteUserName, String? remoteUserAvatar) async {
    try {
      _remoteUserName = remoteUserName;
      _remoteUserAvatar = remoteUserAvatar;
      _callStatus = CallStatus.connecting;
      notifyListeners();

      await _realService.initiateVideoCall(
        receiverId: remoteUserId,
        receiverName: remoteUserName,
        callType: call_model.CallType.video,
      );
      return true;
    } catch (e) {
      _callStatus = CallStatus.failed;
      notifyListeners();
      debugPrint('Error initiating call: $e');
      return false;
    }
  }

  Future<bool> acceptCall(String remoteUserId, String remoteUserName, String? remoteUserAvatar) async {
    try {
      _remoteUserName = remoteUserName;
      _remoteUserAvatar = remoteUserAvatar;
      _callStatus = CallStatus.connecting;
      notifyListeners();

      await _realService.acceptCall();
      return true;
    } catch (e) {
      _callStatus = CallStatus.failed;
      notifyListeners();
      return false;
    }
  }

  Future<void> endCall() async {
    try {
      await _realService.endCall();
      _callStatus = CallStatus.idle;
      _remoteUserName = null;
      _remoteUserAvatar = null;
      _callDuration = Duration.zero;
      notifyListeners();
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  void toggleAudio() {
    _isAudioEnabled = !_isAudioEnabled;
    // Toggle audio tracks on the local stream
    final localStream = _realService.localRenderer.srcObject;
    if (localStream != null) {
      for (final track in localStream.getAudioTracks()) {
        track.enabled = _isAudioEnabled;
      }
    }
    notifyListeners();
  }

  void toggleVideo() {
    _isVideoEnabled = !_isVideoEnabled;
    // Toggle video tracks on the local stream
    final localStream = _realService.localRenderer.srcObject;
    if (localStream != null) {
      for (final track in localStream.getVideoTracks()) {
        track.enabled = _isVideoEnabled;
      }
    }
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerEnabled = !_isSpeakerEnabled;
    notifyListeners();
  }

  Future<void> switchCamera() async {
    // Switch camera on the local video track
    final localStream = _realService.localRenderer.srcObject;
    if (localStream != null) {
      final videoTracks = localStream.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        // ignore: deprecated_member_use
        await videoTracks.first.switchCamera();
      }
    }
    notifyListeners();
  }

  void updateCallDuration(Duration duration) {
    _callDuration = duration;
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _realService.dispose();
    super.dispose();
  }
}
