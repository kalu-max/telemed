import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'config/app_config.dart';
import 'services/notification_service.dart';

enum CallStatus { idle, ringing, connecting, connected, ended }

class DoctorVideoCallService extends ChangeNotifier {
  final String serverUrl;
  final String doctorId;
  final String doctorName;

  io.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  CallStatus _callStatus = CallStatus.idle;
  CallStatus get callStatus => _callStatus;

  String? _currentCallId;
  String? _remoteUserId;
  String? _remoteUserName;
  String get remoteUserName => _remoteUserName ?? 'Patient';

  bool _isAudioEnabled = true;
  bool _isVideoEnabled = true;
  bool _isSpeakerOn = true;
  bool _isFrontCamera = true;

  bool get isAudioEnabled => _isAudioEnabled;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isFrontCamera => _isFrontCamera;

  DateTime? _callStartTime;
  String get callDuration {
    if (_callStartTime == null) return '00:00';
    final diff = DateTime.now().difference(_callStartTime!);
    final mins = diff.inMinutes.toString().padLeft(2, '0');
    final secs = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Timer? _durationTimer;
  List<Map<String, dynamic>> _iceServers = _cloneIceServers(
    AppConfig.iceServers,
  );

  // Pending offer SDP from patient (stored when call:incoming is received)
  String? _pendingOfferSdp;

  // Incoming call callback
  void Function(String callId, String patientId, String patientName)?
      onIncomingCall;

  // New appointment callback
  void Function(Map<String, dynamic> appointment)? onNewAppointment;

  DoctorVideoCallService({
    required this.serverUrl,
    required this.doctorId,
    required this.doctorName,
  });

  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _connectSocket();
  }

  void configureIceServers(List<Map<String, dynamic>> iceServers) {
    final normalized = _cloneIceServers(iceServers);
    if (normalized.isNotEmpty) {
      _iceServers = normalized;
    }
  }

  void _connectSocket() {
    _socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'query': {'userId': doctorId, 'role': 'doctor'},
    });

    _socket!.onConnect((_) {
      debugPrint('[DoctorVideoCall] Socket connected');
      _socket!.emit('user:online', {'userId': doctorId, 'role': 'doctor'});
    });

    _socket!.on('call:incoming', (data) => _handleIncomingCall(data));
    _socket!.on('callAnswered', (data) => _handleCallAnswered(data));
    _socket!.on('call:answered', (data) => _handleCallAnswered(data));
    _socket!.on('offer', (data) => _handleOffer(data));
    _socket!.on('answer', (data) => _handleAnswer(data));
    _socket!.on('iceCandidate', (data) => _handleIceCandidate(data));
    _socket!.on('callRejected', (_) => _handleCallEnded());
    _socket!.on('callFailed', (data) => _handleCallFailed(data));
    _socket!.on('call:error', (data) => _handleCallFailed(data));
    _socket!.on('callEnded', (_) => _handleCallEnded());
    _socket!.on('call:ended', (_) => _handleCallEnded());

    _socket!.on('newAppointment', (data) {
      final appt =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      onNewAppointment?.call(appt);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[DoctorVideoCall] Socket disconnected');
    });
  }

  // --- Incoming call from patient ---
  void _handleIncomingCall(dynamic data) {
    if (data is! Map) return;
    final callId = data['callId']?.toString() ?? '';
    final callerId =
        data['callerId']?.toString() ?? data['patientId']?.toString() ?? '';
    final callerName = data['callerName']?.toString() ??
        data['patientName']?.toString() ??
        'Patient';

    // Apply ICE servers sent by the backend (includes TURN when configured)
    final iceList = data['iceServers'];
    if (iceList is List && iceList.isNotEmpty) {
      configureIceServers(
        iceList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    }

    // Store SDP offer if provided (patient sent it with initiateCall)
    final offerRaw = data['offer'];
    if (offerRaw is String && offerRaw.isNotEmpty) {
      _pendingOfferSdp = offerRaw;
    } else if (offerRaw is Map) {
      _pendingOfferSdp = offerRaw['sdp']?.toString();
    } else {
      _pendingOfferSdp = null;
    }

    _currentCallId = callId;
    _remoteUserId = callerId;
    _remoteUserName = callerName;
    _callStatus = CallStatus.ringing;
    notifyListeners();

    // Show local notification for incoming call
    NotificationService.instance.show(
      title: 'Incoming Call',
      body: '$callerName is calling you',
      id: callId.hashCode % 100000,
    );

    onIncomingCall?.call(callId, callerId, callerName);
  }

  // --- Doctor initiates call to patient ---
  Future<void> initiateCall(String patientId, String patientName) async {
    _remoteUserId = patientId;
    _remoteUserName = patientName;
    _callStatus = CallStatus.connecting;
    notifyListeners();

    await _setupLocalMedia();
    await _createPeerConnection();

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _socket?.emit('initiateCall', {
      'callerId': doctorId,
      'callerName': doctorName,
      'receiverId': patientId,
      'receiverName': patientName,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  // --- Accept incoming call ---
  Future<void> acceptCall() async {
    _callStatus = CallStatus.connecting;
    notifyListeners();

    await _setupLocalMedia();
    await _createPeerConnection();

    if (_pendingOfferSdp != null) {
      // Patient sent their offer — set it as remote description and create answer
      final remote = RTCSessionDescription(_pendingOfferSdp!, 'offer');
      await _peerConnection!.setRemoteDescription(remote);
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _pendingOfferSdp = null;

      _socket?.emit('answerCall', {
        'callId': _currentCallId,
        'callerId': _remoteUserId,
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });
    } else {
      _socket?.emit('answerCall', {
        'callId': _currentCallId,
        'callerId': _remoteUserId,
      });
    }
  }

  // --- Reject incoming call ---
  void rejectCall() {
    _socket?.emit('rejectCall', {
      'callId': _currentCallId,
      'senderId': doctorId,
    });
    _cleanup();
  }

  // --- End ongoing call ---
  void endCall() {
    _socket?.emit('endCall', {
      'callId': _currentCallId,
      'senderId': doctorId,
    });
    _cleanup();
  }

  // --- Handle WebRTC offer (when patient calls) ---
  Future<void> _handleOffer(dynamic data) async {
    if (data is! Map) return;
    final offerMap = data['offer'] ?? data;
    if (offerMap['sdp'] == null) return;

    if (_peerConnection == null) {
      await _setupLocalMedia();
      await _createPeerConnection();
    }

    final description = RTCSessionDescription(
      offerMap['sdp'],
      offerMap['type'] ?? 'offer',
    );
    await _peerConnection!.setRemoteDescription(description);

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socket?.emit('answer', {
      'callId': _currentCallId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
      'recipientId': _remoteUserId,
    });
  }

  // --- Handle WebRTC answer ---
  Future<void> _handleAnswer(dynamic data) async {
    if (data is! Map) return;
    final answerMap = data['answer'] ?? data;
    if (answerMap['sdp'] == null) return;

    final description = RTCSessionDescription(
      answerMap['sdp'],
      answerMap['type'] ?? 'answer',
    );
    await _peerConnection?.setRemoteDescription(description);
  }

  Future<void> _handleCallAnswered(dynamic data) async {
    if (data is Map && data['answer'] != null) {
      await _handleAnswer({'answer': data['answer']});
    }

    if (_callStatus == CallStatus.ringing ||
        _callStatus == CallStatus.connecting) {
      _callStatus = CallStatus.connecting;
      notifyListeners();
    }

    debugPrint('[DoctorVideoCall] Call answered');
  }

  // --- Handle ICE candidate ---
  Future<void> _handleIceCandidate(dynamic data) async {
    if (data is! Map) return;
    final candidateStr = data['candidate'];
    if (candidateStr == null) return;

    final candidate = RTCIceCandidate(
      candidateStr,
      data['sdpMid']?.toString() ?? '',
      data['sdpMlineIndex'] ?? 0,
    );
    await _peerConnection?.addCandidate(candidate);
  }

  void _handleCallEnded() {
    _cleanup();
  }

  // --- Setup local media ---
  Future<void> _setupLocalMedia() async {
    final constraints = {
      'audio': {'echoCancellation': true},
      'video': {
        'facingMode': 'user',
        'mandatory': {
          'minWidth': 640,
          'minHeight': 480,
          'minFrameRate': 24,
        },
      },
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = _localStream;
  }

  // --- Create peer connection ---
  Future<void> _createPeerConnection() async {
    final configuration = {
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    // Add local tracks
    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // Handle remote stream
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        notifyListeners();
      }
    };

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (candidate) {
      _socket?.emit('iceCandidate', {
        'callId': _currentCallId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMlineIndex': candidate.sdpMLineIndex,
        'recipientId': _remoteUserId,
      });
    };

    // Connection state
    _peerConnection!.onConnectionState = (state) {
      debugPrint('[DoctorVideoCall] Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _callStatus = CallStatus.connected;
        _callStartTime = DateTime.now();
        _startDurationTimer();
        notifyListeners();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _cleanup();
      }
    };
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  // --- Toggle controls ---
  void toggleAudio() {
    _isAudioEnabled = !_isAudioEnabled;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = _isAudioEnabled;
    });
    notifyListeners();
  }

  void toggleVideo() {
    _isVideoEnabled = !_isVideoEnabled;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = _isVideoEnabled;
    });
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    _localStream?.getAudioTracks().forEach((track) {
      track.enableSpeakerphone(_isSpeakerOn);
    });
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
      _isFrontCamera = !_isFrontCamera;
      notifyListeners();
    }
  }

  // --- Cleanup ---
  void _cleanup() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _callStartTime = null;

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    _remoteStream = null;

    _peerConnection?.close();
    _peerConnection = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    _currentCallId = null;
    _remoteUserId = null;
    _remoteUserName = null;
    _callStatus = CallStatus.idle;
    notifyListeners();
  }

  void _handleCallFailed(dynamic data) {
    final reason = data is Map ? data['reason']?.toString() : null;
    if (reason != null && reason.isNotEmpty) {
      debugPrint('[DoctorVideoCall] Call failed: $reason');
    } else {
      debugPrint('[DoctorVideoCall] Call failed');
    }
    _cleanup();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _cleanup();
    _socket?.disconnect();
    _socket?.dispose();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }

  static List<Map<String, dynamic>> _cloneIceServers(
    List<Map<String, dynamic>> iceServers,
  ) {
    return iceServers
        .map((server) {
          final urls = server['urls'] ?? server['url'];
          if (urls == null) {
            return null;
          }

          final normalized = <String, dynamic>{
            'urls': urls is List ? List<dynamic>.from(urls) : [urls],
          };

          if (server['username'] != null) {
            normalized['username'] = server['username'];
          }
          if (server['credential'] != null) {
            normalized['credential'] = server['credential'];
          }

          return normalized;
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }
}
