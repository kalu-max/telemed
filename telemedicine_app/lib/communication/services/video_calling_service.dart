import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/call_model.dart';
import '../services/bandwidth_optimization_service.dart';

/// Service for video calling with adaptive bitrate streaming
class VideoCallingService {
  final String signalingServerUrl;
  io.Socket? _socket;
  String userId;
  String userName;
  final BandwidthOptimizationService bandwidthService;
  
  late RTCPeerConnection _peerConnection;
  late final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  late final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  final StreamController<CallSession> _callStateController = StreamController<CallSession>.broadcast();
  final StreamController<RTCIceCandidate> _iceCandidateController = StreamController<RTCIceCandidate>.broadcast();
  final StreamController<CallStatistics> _statsController = StreamController<CallStatistics>.broadcast();
  final StreamController<VideoQuality> _qualityChangeController = StreamController<VideoQuality>.broadcast();
  
  CallSession? _currentCall;
  VideoQuality _currentVideoQuality = VideoQuality.medium;
  Timer? _statsTimer;
  
  final uuid = const Uuid();

  VideoCallingService({
    required this.signalingServerUrl,
    required this.userId,
    required this.userName,
    required this.bandwidthService,
    io.Socket? socket,
  }) : _socket = socket;

  /// Initialize video calling service
  Future<void> initialize() async {
    try {
      // Initialize renderers
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      
      // Initialize socket if not already provided
      _socket ??= io.io(
        signalingServerUrl,
        <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': true,
          'query': {'userId': userId, 'role': 'patient'},
        },
      );
      
      // Setup socket listeners
      _setupSocketListeners();
    } catch (e) {
      throw Exception('Failed to initialize video calling service: $e');
    }
  }

  /// Setup socket event listeners
  void _setupSocketListeners() {
    if (_socket == null) return;
    
    _socket!.on('offer', (data) {
      _handleOffer(data);
    });

    _socket!.on('answer', (data) {
      _handleAnswer(data);
    });

    _socket!.on('iceCandidate', (data) {
      _handleIceCandidate(data);
    });

    _socket!.on('callRejected', (_) {
      _handleCallRejected();
    });

    _socket!.on('callEnded', (_) {
      _handleCallEnded();
    });
  }

  /// Get socket instance
  io.Socket? get socket => _socket;

  /// Initiate a video call
  Future<void> initiateVideoCall({
    required String receiverId,
    required String receiverName,
    CallType callType = CallType.video,
  }) async {
    try {
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

      // Create peer connection
      await _createPeerConnection();

      // Get local media
      await _getLocalMedia();

      // Create offer
      final offer = await _peerConnection.createOffer();
      await _peerConnection.setLocalDescription(offer);

      // Send offer via socket
      _socket?.emit('initiateCall', {
        'callId': callId,
        'callerId': userId,
        'callerName': userName,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'callType': callType.toString().split('.').last,
        'offer': offer.sdp,
      });

      _currentCall!.status = CallStatus.ringing;
      _callStateController.add(_currentCall!);
      
      // Start collecting statistics
      _startStatsCollection();
    } catch (e) {
      throw Exception('Failed to initiate video call: $e');
    }
  }

  /// Handle incoming call offer
  Future<void> _handleOffer(dynamic data) async {
    try {
      final callId = data['callId'];
      final callerId = data['callerId'];
      final callerName = data['callerName'];
      final offer = data['offer'];

      _currentCall = CallSession(
        id: callId,
        callerId: callerId,
        callerName: callerName,
        receiverId: userId,
        receiverName: userName,
        callType: _parseCallType(data['callType'] ?? 'audio'),
        direction: CallDirection.incoming,
        initiatedAt: DateTime.now(),
        status: CallStatus.ringing,
      );

      // Create peer connection
      await _createPeerConnection();

      // Set remote description
      final sessionDescription = RTCSessionDescription(
        offer,
        'offer',
      );
      await _peerConnection.setRemoteDescription(sessionDescription);

      // Create answer
      final answer = await _peerConnection.createAnswer();
      await _peerConnection.setLocalDescription(answer);

      // Get local media
      await _getLocalMedia();

      // Send answer
      _socket?.emit('answerCall', {
        'callId': callId,
        'answer': answer.sdp,
      });

      _callStateController.add(_currentCall!);
    } catch (e) {
      throw Exception('Failed to handle offer: $e');
    }
  }

  /// Handle answer to our offer
  Future<void> _handleAnswer(dynamic data) async {
    try {
      final answer = data['answer'];
      
      final sessionDescription = RTCSessionDescription(answer, 'answer');
      await _peerConnection.setRemoteDescription(sessionDescription);
      
      _currentCall?.status = CallStatus.connecting;
      _callStateController.add(_currentCall!);
    } catch (e) {
      throw Exception('Failed to handle answer: $e');
    }
  }

  /// Handle ICE candidate
  Future<void> _handleIceCandidate(dynamic data) async {
    try {
      final candidate = RTCIceCandidate(
        data['candidate'],
        data['sdpMlineIndex'],
        data['sdpMid'],
      );
      
      await _peerConnection.addCandidate(candidate);
    } catch (e) {
      // Error handled: failed to process ICE candidate
    }
  }

  /// Accept incoming call
  Future<void> acceptCall() async {
    try {
      if (_currentCall?.status == CallStatus.ringing &&
          _currentCall?.direction == CallDirection.incoming) {
        _currentCall!.status = CallStatus.accepted;
        _callStateController.add(_currentCall!);
      }
    } catch (e) {
      throw Exception('Failed to accept call: $e');
    }
  }

  /// Reject incoming call
  Future<void> rejectCall() async {
    try {
      _socket?.emit('rejectCall', {
        'callId': _currentCall?.id,
        'senderId': userId,
      });
      
      await _cleanup();
    } catch (e) {
      throw Exception('Failed to reject call: $e');
    }
  }

  /// End current call
  Future<void> endCall() async {
    try {
      _socket?.emit('endCall', {
        'callId': _currentCall?.id,
        'senderId': userId,
      });

      _currentCall?.status = CallStatus.ended;
      _currentCall?.endedAt = DateTime.now();
      if (_currentCall?.startedAt != null) {
        _currentCall!.duration = _currentCall!.endedAt!.difference(_currentCall!.startedAt!);
      }
      
      _callStateController.add(_currentCall!);
      
      await _cleanup();
    } catch (e) {
      throw Exception('Failed to end call: $e');
    }
  }

  /// Create peer connection with adaptive bitrate configuration
  Future<void> _createPeerConnection() async {
    try {
      final configuration = {
        'iceServers': [
          {'urls': ['stun:stun.l.google.com:19302']},
          {'urls': ['stun:stun1.l.google.com:19302']},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      _peerConnection.onIceCandidate = (candidate) {
        _socket?.emit('iceCandidate', {
          'callId': _currentCall?.id,
          'candidate': candidate.candidate,
          'sdpMlineIndex': candidate.sdpMLineIndex ?? 0,
          'sdpMid': candidate.sdpMid,
          'recipientId': _currentCall?.receiverId,
        });
      };

      _peerConnection.onConnectionState = (state) {
        _handleConnectionStateChange(state);
      };

      _peerConnection.onTrack = (event) {
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
      };
    } catch (e) {
      throw Exception('Failed to create peer connection: $e');
    }
  }

  /// Handle connection state changes
  void _handleConnectionStateChange(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _currentCall?.status = CallStatus.connected;
        _currentCall?.startedAt = DateTime.now();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        _currentCall?.status = CallStatus.disconnected;
        break;
      default:
        break;
    }
    if (_currentCall != null) {
      _callStateController.add(_currentCall!);
    }
  }

  /// Get local media stream
  Future<void> _getLocalMedia() async {
    try {
      final constraints = {
        'audio': {'echoCancellation': true},
        'video': {
          'mandatory': {
            'minWidth': 320,
            'minHeight': 240,
            'minFrameRate': 15,
          },
          'facingMode': 'user',
        }
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localRenderer.srcObject = _localStream;

      // Add tracks to peer connection
      for (final track in _localStream!.getTracks()) {
        await _peerConnection.addTrack(track, _localStream!);
      }
    } catch (e) {
      throw Exception('Failed to get local media: $e');
    }
  }

  /// Start collecting call statistics
  void _startStatsCollection() {
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final stats = await _peerConnection.getStats();
        await _updateBitrateAndQuality(stats);
      } catch (e) {
        // Error handled: failed to collect stats
      }
    });
  }

  /// Update bitrate and video quality based on network condition
  Future<void> _updateBitrateAndQuality(List<StatsReport> stats) async {
    try {
      final metrics = bandwidthService.getMovingAverageMetrics();
      final newQuality = bandwidthService.selectOptimalVideoQuality(metrics);

      if (newQuality != _currentVideoQuality) {
        _currentVideoQuality = newQuality;
        _qualityChangeController.add(newQuality);
        await _adjustVideoQuality(newQuality);
      }

      // Create call statistics
      final callStats = CallStatistics(
        callId: _currentCall?.id ?? '',
        avgBitrate: metrics.downstreamBandwidth * 1000,
        avgLatency: metrics.latency,
        packetLoss: metrics.packetLoss,
        timestamp: DateTime.now(),
        currentVideoQuality: newQuality,
      );

      _statsController.add(callStats);
    } catch (e) {
      // Error handled: failed to update quality
    }
  }

  /// Adjust video quality dynamically
  Future<void> _adjustVideoQuality(VideoQuality quality) async {
    try {
      for (final sender in await _peerConnection.getSenders()) {
        if (sender.track?.kind == 'video') {
          final parameters = sender.parameters;
          if (parameters.encodings != null) {
            for (final encoding in parameters.encodings!) {
              encoding.maxBitrate = quality.bitrate;
              encoding.maxFramerate = quality.fps;
            }
          }
          await sender.setParameters(parameters);
        }
      }
    } catch (e) {
      // Error handled: failed to adjust video quality
    }
  }

  /// Handle call rejection
  void _handleCallRejected() async {
    _currentCall?.status = CallStatus.rejected;
    _callStateController.add(_currentCall!);
    await _cleanup();
  }

  /// Handle call ended
  void _handleCallEnded() async {
    _currentCall?.status = CallStatus.ended;
    _currentCall?.endedAt = DateTime.now();
    if (_currentCall?.startedAt != null) {
      _currentCall!.duration = _currentCall!.endedAt!.difference(_currentCall!.startedAt!);
    }
    _callStateController.add(_currentCall!);
    await _cleanup();
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    _statsTimer?.cancel();
    
    for (final track in _localStream?.getTracks() ?? []) {
      track.stop();
    }
    
    await _peerConnection.close();
  }

  /// Get call state stream
  Stream<CallSession> get callStateStream => _callStateController.stream;

  /// Get video quality change stream
  Stream<VideoQuality> get qualityChangeStream => _qualityChangeController.stream;

  /// Get statistics stream
  Stream<CallStatistics> get statsStream => _statsController.stream;

  /// Get local renderer
  RTCVideoRenderer get localRenderer => _localRenderer;

  /// Get remote renderer
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  /// Get current call
  CallSession? get currentCall => _currentCall;

  /// Dispose resources
  Future<void> dispose() async {
    _statsTimer?.cancel();
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
    _callStateController.close();
    _iceCandidateController.close();
    _statsController.close();
    _qualityChangeController.close();
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
