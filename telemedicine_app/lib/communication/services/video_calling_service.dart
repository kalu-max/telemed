import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../models/call_model.dart';
import '../services/bandwidth_optimization_service.dart';

/// Service for video calling with adaptive bitrate streaming.
class VideoCallingService {
  final String signalingServerUrl;
  final BandwidthOptimizationService bandwidthService;

  io.Socket? _socket;
  String userId;
  String userName;
  String role;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final StreamController<CallSession> _callStateController =
      StreamController<CallSession>.broadcast();
  final StreamController<CallStatistics> _statsController =
      StreamController<CallStatistics>.broadcast();
  final StreamController<VideoQuality> _qualityChangeController =
      StreamController<VideoQuality>.broadcast();

  CallSession? _currentCall;
  VideoQuality _currentVideoQuality = VideoQuality.medium;
  Timer? _statsTimer;

  final Uuid uuid = const Uuid();

  bool _isInitialized = false;
  bool _remoteAnswerApplied = false;
  String? _pendingOfferSdp;
  String _pendingOfferType = 'offer';
  List<Map<String, dynamic>> _iceServers = _cloneIceServers(
    AppConfig.iceServers,
  );

  VideoCallingService({
    required this.signalingServerUrl,
    required this.userId,
    required this.userName,
    required this.bandwidthService,
    this.role = 'patient',
    io.Socket? socket,
  }) : _socket = socket;

  /// Initialize renderers and socket connection.
  Future<void> initialize() async {
    if (!_isInitialized) {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      _isInitialized = true;
    }

    if (_socket == null) {
      _connectSocket();
    } else if (!(_socket?.connected ?? false)) {
      _socket?.connect();
    }
  }

  /// Update socket identity after login or role changes.
  Future<void> updateSession({
    required String userId,
    required String userName,
    String role = 'patient',
  }) async {
    final nextUserId = userId.trim().isEmpty ? 'guest' : userId.trim();
    final nextUserName = userName.trim().isEmpty ? 'Patient' : userName.trim();
    final nextRole = role.trim().isEmpty ? 'patient' : role.trim();

    final identityChanged =
        this.userId != nextUserId ||
        this.userName != nextUserName ||
        this.role != nextRole;

    this.userId = nextUserId;
    this.userName = nextUserName;
    this.role = nextRole;

    await initialize();

    if (identityChanged) {
      _disposeSocket();
      _connectSocket();
    }
  }

  void configureIceServers(List<Map<String, dynamic>> iceServers) {
    final normalized = _cloneIceServers(iceServers);
    if (normalized.isNotEmpty) {
      _iceServers = normalized;
    }
  }

  /// Get socket instance.
  io.Socket? get socket => _socket;

  /// Initiate an outgoing video or audio call.
  Future<void> initiateVideoCall({
    required String receiverId,
    required String receiverName,
    CallType callType = CallType.video,
  }) async {
    try {
      await initialize();
      await _resetConnectionArtifacts();

      final callId = uuid.v4();
      _currentCall = CallSession(
        id: callId,
        callerId: userId,
        callerName: userName,
        receiverId: receiverId,
        receiverName: receiverName,
        callType: callType,
        direction: CallDirection.outgoing,
        initiatedAt: DateTime.now(),
        status: CallStatus.initiating,
      );
      _callStateController.add(_currentCall!);

      await _createPeerConnection();
      await _getLocalMedia(callType: callType);

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _socket?.emit('initiateCall', {
        'callId': callId,
        'callerId': userId,
        'callerName': userName,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'callType': callType.toString().split('.').last,
        'offer': {'sdp': offer.sdp, 'type': offer.type},
      });

      _currentCall!.status = CallStatus.ringing;
      _callStateController.add(_currentCall!);
      _startStatsCollection();
    } catch (e) {
      await _markCallAsFailed();
      throw Exception('Failed to initiate video call: $e');
    }
  }

  /// Accept the current incoming call.
  Future<void> acceptCall() async {
    try {
      final currentCall = _currentCall;
      if (currentCall == null ||
          currentCall.direction != CallDirection.incoming ||
          _pendingOfferSdp == null) {
        throw Exception('No incoming call is ready to be accepted');
      }

      await initialize();
      await _createPeerConnection();
      await _getLocalMedia(callType: currentCall.callType);

      final remoteDescription = RTCSessionDescription(
        _pendingOfferSdp!,
        _pendingOfferType,
      );
      await _peerConnection!.setRemoteDescription(remoteDescription);

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _currentCall!.status = CallStatus.connecting;
      _callStateController.add(_currentCall!);

      _socket?.emit('answerCall', {
        'callId': currentCall.id,
        'callerId': currentCall.callerId,
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });

      _pendingOfferSdp = null;
      _pendingOfferType = 'offer';
      _startStatsCollection();
    } catch (e) {
      await _markCallAsFailed();
      throw Exception('Failed to accept call: $e');
    }
  }

  /// Reject the current incoming call.
  Future<void> rejectCall() async {
    try {
      _socket?.emit('rejectCall', {
        'callId': _currentCall?.id,
        'senderId': userId,
      });

      _currentCall?.status = CallStatus.rejected;
      if (_currentCall != null) {
        _callStateController.add(_currentCall!);
      }

      await _cleanup();
    } catch (e) {
      throw Exception('Failed to reject call: $e');
    }
  }

  /// End the current call.
  Future<void> endCall() async {
    try {
      _socket?.emit('endCall', {
        'callId': _currentCall?.id,
        'senderId': userId,
      });

      if (_currentCall != null) {
        _markCallFinished(CallStatus.ended);
        _callStateController.add(_currentCall!);
      }

      await _cleanup();
    } catch (e) {
      throw Exception('Failed to end call: $e');
    }
  }

  void _connectSocket() {
    _socket = io.io(signalingServerUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'query': {'userId': userId, 'role': role},
    });

    _setupSocketListeners();
    _socket?.connect();
  }

  void _disposeSocket() {
    final socket = _socket;
    if (socket == null) {
      return;
    }

    socket.disconnect();
    socket.dispose();
    _socket = null;
  }

  void _setupSocketListeners() {
    final socket = _socket;
    if (socket == null) {
      return;
    }

    socket.on('call:incoming', _handleIncomingCall);
    socket.on('offer', (data) {
      _handleOffer(data);
    });
    socket.on('answer', (data) {
      _handleAnswer(data);
    });
    socket.on('callAnswered', (data) {
      _handleCallAnswered(data);
    });
    socket.on('call:answered', (data) {
      _handleCallAnswered(data);
    });
    socket.on('iceCandidate', (data) {
      _handleIceCandidate(data);
    });
    socket.on('callRejected', (_) {
      _handleCallRejected();
    });
    socket.on('callEnded', (_) {
      _handleCallEnded();
    });
    socket.on('callFailed', (data) {
      _handleCallFailure(data);
    });
    socket.on('call:error', (data) {
      _handleCallFailure(data);
    });
  }

  void _handleIncomingCall(dynamic data) {
    final callData = _asMap(data);
    if (callData.isEmpty) {
      return;
    }

    // Apply ICE servers sent by the backend (includes TURN when configured)
    final iceList = callData['iceServers'];
    if (iceList is List && iceList.isNotEmpty) {
      configureIceServers(
        iceList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    }

    _ensureIncomingCall(callData);
    _storePendingOffer(callData['offer']);
  }

  void _handleOffer(dynamic data) {
    final offerData = _asMap(data);
    if (offerData.isEmpty) {
      return;
    }

    _ensureIncomingCall(offerData);
    _storePendingOffer(offerData['offer'] ?? offerData);
  }

  Future<void> _handleAnswer(dynamic data) async {
    try {
      if (_peerConnection == null || _remoteAnswerApplied) {
        return;
      }

      final payload = _asMap(data);
      final answerPayload = payload['answer'] ?? payload;
      final answerSdp = _extractSessionSdp(answerPayload);
      if (answerSdp == null || answerSdp.isEmpty) {
        return;
      }

      final description = RTCSessionDescription(
        answerSdp,
        _extractSessionType(answerPayload, fallbackType: 'answer'),
      );
      await _peerConnection!.setRemoteDescription(description);

      _remoteAnswerApplied = true;
      if (_currentCall != null) {
        _currentCall!.status = CallStatus.connecting;
        _callStateController.add(_currentCall!);
      }
    } catch (_) {
      // Duplicate or malformed answers are ignored because multiple signaling
      // handlers in the backend may relay the same payload more than once.
    }
  }

  Future<void> _handleCallAnswered(dynamic data) async {
    final payload = _asMap(data);
    if (payload['answer'] != null) {
      await _handleAnswer(payload);
    }

    if (_currentCall != null &&
        _currentCall!.direction == CallDirection.outgoing &&
        _currentCall!.status == CallStatus.ringing) {
      _currentCall!.status = CallStatus.connecting;
      _callStateController.add(_currentCall!);
    }
  }

  Future<void> _handleIceCandidate(dynamic data) async {
    try {
      final candidateData = _asMap(data);
      final candidateValue = candidateData['candidate']?.toString();
      if (_peerConnection == null ||
          candidateValue == null ||
          candidateValue.isEmpty) {
        return;
      }

      final candidate = RTCIceCandidate(
        candidateValue,
        candidateData['sdpMid']?.toString(),
        candidateData['sdpMlineIndex'] as int?,
      );
      await _peerConnection!.addCandidate(candidate);
    } catch (_) {
      // Invalid ICE candidates are ignored to keep the call alive when one of
      // the duplicated socket handlers forwards incomplete data.
    }
  }

  Future<void> _createPeerConnection() async {
    await _disposePeerConnection();

    final configuration = {
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (candidate) {
      final targetUserId = _remoteParticipantId;
      if (targetUserId == null || candidate.candidate == null) {
        return;
      }

      _socket?.emit('iceCandidate', {
        'callId': _currentCall?.id,
        'candidate': candidate.candidate,
        'sdpMlineIndex': candidate.sdpMLineIndex,
        'sdpMid': candidate.sdpMid,
        'recipientId': targetUserId,
        'targetUserId': targetUserId,
      });
    };

    _peerConnection!.onConnectionState = (state) {
      _handleConnectionStateChange(state);
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isEmpty) {
        return;
      }
      _remoteStream = event.streams.first;
      _remoteRenderer.srcObject = _remoteStream;
    };
  }

  void _handleConnectionStateChange(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        if (_currentCall != null) {
          _currentCall!.status = CallStatus.connected;
          _currentCall!.startedAt ??= DateTime.now();
          _callStateController.add(_currentCall!);
        }
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        if (_currentCall != null) {
          _markCallFinished(CallStatus.disconnected);
          _callStateController.add(_currentCall!);
        }
        unawaited(_releaseMediaResources());
        break;
      default:
        break;
    }
  }

  Future<void> _getLocalMedia({required CallType callType}) async {
    await _disposeLocalStream();

    final constraints = {
      'audio': {'echoCancellation': true},
      'video': callType == CallType.audio
          ? false
          : {
              'mandatory': {
                'minWidth': 320,
                'minHeight': 240,
                'minFrameRate': 15,
              },
              'facingMode': 'user',
            },
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    _localRenderer.srcObject = _localStream;

    final peerConnection = _peerConnection;
    if (peerConnection == null || _localStream == null) {
      return;
    }

    for (final track in _localStream!.getTracks()) {
      await peerConnection.addTrack(track, _localStream!);
    }
  }

  void _startStatsCollection() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_peerConnection == null) {
        return;
      }

      try {
        final stats = await _peerConnection!.getStats();
        await _updateBitrateAndQuality(stats);
      } catch (_) {
        // Stats collection should not interrupt an active call.
      }
    });
  }

  Future<void> _updateBitrateAndQuality(List<StatsReport> stats) async {
    try {
      final metrics = bandwidthService.getMovingAverageMetrics();
      final newQuality = bandwidthService.selectOptimalVideoQuality(metrics);

      if (newQuality != _currentVideoQuality) {
        _currentVideoQuality = newQuality;
        _qualityChangeController.add(newQuality);
        await _adjustVideoQuality(newQuality);
      }

      final callStats = CallStatistics(
        callId: _currentCall?.id ?? '',
        avgBitrate: metrics.downstreamBandwidth * 1000,
        avgLatency: metrics.latency,
        packetLoss: metrics.packetLoss,
        timestamp: DateTime.now(),
        currentVideoQuality: newQuality,
      );

      _statsController.add(callStats);
    } catch (_) {
      // Adaptive bitrate should fail soft.
    }
  }

  Future<void> _adjustVideoQuality(VideoQuality quality) async {
    final peerConnection = _peerConnection;
    if (peerConnection == null) {
      return;
    }

    try {
      for (final sender in await peerConnection.getSenders()) {
        if (sender.track?.kind != 'video') {
          continue;
        }

        final parameters = sender.parameters;
        if (parameters.encodings == null) {
          continue;
        }

        for (final encoding in parameters.encodings!) {
          encoding.maxBitrate = quality.bitrate;
          encoding.maxFramerate = quality.fps;
        }

        await sender.setParameters(parameters);
      }
    } catch (_) {
      // Quality changes are best-effort and should not break the call.
    }
  }

  Future<void> _handleCallRejected() async {
    if (_currentCall != null) {
      _currentCall!.status = CallStatus.rejected;
      _callStateController.add(_currentCall!);
    }
    await _cleanup();
  }

  Future<void> _handleCallEnded() async {
    if (_currentCall != null) {
      _markCallFinished(CallStatus.ended);
      _callStateController.add(_currentCall!);
    }
    await _cleanup();
  }

  Future<void> _handleCallFailure(dynamic data) async {
    await _markCallAsFailed();
  }

  Future<void> _markCallAsFailed() async {
    if (_currentCall != null) {
      _markCallFinished(CallStatus.failed);
      _callStateController.add(_currentCall!);
    }
    await _cleanup();
  }

  void _ensureIncomingCall(Map<String, dynamic> data) {
    final callId = data['callId']?.toString() ?? _currentCall?.id ?? uuid.v4();
    final callerId =
        data['callerId']?.toString() ?? data['senderId']?.toString() ?? '';
    final callerName = data['callerName']?.toString() ?? 'Doctor';
    final callType = _parseCallType(
      data['callType']?.toString() ??
          _currentCall?.callType.toString().split('.').last ??
          'video',
    );

    if (_currentCall != null &&
        _currentCall!.id == callId &&
        _currentCall!.direction == CallDirection.incoming) {
      _currentCall!.callerId = callerId;
      _currentCall!.callerName = callerName;
      _currentCall!.receiverId = userId;
      _currentCall!.receiverName = userName;
      _currentCall!.callType = callType;

      const activeStatuses = <CallStatus>{
        CallStatus.accepted,
        CallStatus.connecting,
        CallStatus.connected,
      };
      if (!activeStatuses.contains(_currentCall!.status)) {
        _currentCall!.status = CallStatus.ringing;
      }
    } else {
      _currentCall = CallSession(
        id: callId,
        callerId: callerId,
        callerName: callerName,
        receiverId: userId,
        receiverName: userName,
        callType: callType,
        direction: CallDirection.incoming,
        initiatedAt: DateTime.now(),
        status: CallStatus.ringing,
      );
    }

    if (_currentCall != null) {
      _callStateController.add(_currentCall!);
    }
  }

  void _storePendingOffer(dynamic offerPayload) {
    final sdp = _extractSessionSdp(offerPayload);
    if (sdp == null || sdp.isEmpty) {
      return;
    }

    _pendingOfferSdp = sdp;
    _pendingOfferType = _extractSessionType(
      offerPayload,
      fallbackType: 'offer',
    );
    _remoteAnswerApplied = false;
  }

  Future<void> _cleanup() async {
    _statsTimer?.cancel();
    _statsTimer = null;
    await _releaseMediaResources();
    _pendingOfferSdp = null;
    _pendingOfferType = 'offer';
    _remoteAnswerApplied = false;
  }

  Future<void> _resetConnectionArtifacts() async {
    _statsTimer?.cancel();
    _statsTimer = null;
    _pendingOfferSdp = null;
    _pendingOfferType = 'offer';
    _remoteAnswerApplied = false;
    await _releaseMediaResources();
  }

  Future<void> _releaseMediaResources() async {
    await _disposePeerConnection();
    await _disposeLocalStream();

    _remoteStream = null;
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
  }

  Future<void> _disposePeerConnection() async {
    final peerConnection = _peerConnection;
    if (peerConnection == null) {
      return;
    }

    await peerConnection.close();
    _peerConnection = null;
  }

  Future<void> _disposeLocalStream() async {
    final localStream = _localStream;
    if (localStream == null) {
      return;
    }

    for (final track in localStream.getTracks()) {
      track.stop();
    }
    await localStream.dispose();
    _localStream = null;
  }

  void _markCallFinished(CallStatus status) {
    if (_currentCall == null) {
      return;
    }

    final endedAt = DateTime.now();
    _currentCall!.status = status;
    _currentCall!.endedAt = endedAt;

    if (_currentCall!.startedAt != null) {
      _currentCall!.duration = endedAt.difference(_currentCall!.startedAt!);
    }
  }

  String? _getRemoteParticipantId() {
    final currentCall = _currentCall;
    if (currentCall == null) {
      return null;
    }

    return currentCall.direction == CallDirection.incoming
        ? currentCall.callerId
        : currentCall.receiverId;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  String? _extractSessionSdp(dynamic payload) {
    if (payload is String) {
      return payload;
    }
    if (payload is Map) {
      return payload['sdp']?.toString();
    }
    return null;
  }

  String _extractSessionType(dynamic payload, {required String fallbackType}) {
    if (payload is Map && payload['type'] != null) {
      return payload['type'].toString();
    }
    return fallbackType;
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

  /// Get call state stream.
  Stream<CallSession> get callStateStream => _callStateController.stream;

  /// Get video quality change stream.
  Stream<VideoQuality> get qualityChangeStream =>
      _qualityChangeController.stream;

  /// Get statistics stream.
  Stream<CallStatistics> get statsStream => _statsController.stream;

  /// Get local renderer.
  RTCVideoRenderer get localRenderer => _localRenderer;

  /// Get remote renderer.
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  /// Get current call.
  CallSession? get currentCall => _currentCall;

  String? get _remoteParticipantId => _getRemoteParticipantId();

  /// Dispose resources.
  Future<void> dispose() async {
    _statsTimer?.cancel();
    await _releaseMediaResources();
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
    _disposeSocket();
    await _callStateController.close();
    await _statsController.close();
    await _qualityChangeController.close();
  }

  static CallType _parseCallType(String type) {
    switch (type) {
      case 'video':
        return CallType.video;
      case 'groupVideo':
        return CallType.groupVideo;
      default:
        return CallType.audio;
    }
  }
}
