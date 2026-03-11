import 'dart:async';
import 'video_calling_service.dart';
import '../models/call_model.dart';

/// Web-based video calling service that delegates to VideoCallingService
/// Provides the same interface for web platforms using WebRTC
class WebVideoCallingService {
  VideoCallingService? _videoCallingService;
  bool _isInCall = false;

  final StreamController<bool> _callStatusStream = StreamController.broadcast();
  final StreamController<String> _messageStream = StreamController.broadcast();

  Stream<bool> get callStatusStream => _callStatusStream.stream;
  Stream<String> get messageStream => _messageStream.stream;

  /// Initialize the video calling service
  Future<void> initialize({
    required String userId,
    required String userName,
    VideoCallingService? videoCallingService,
  }) async {
    _videoCallingService = videoCallingService;
  }

  /// Initiate a video call via WebRTC
  Future<void> initiateVideoCall({
    required String receiverId,
    required String receiverName,
  }) async {
    try {
      if (_videoCallingService != null) {
        await _videoCallingService!.initiateVideoCall(
          receiverId: receiverId,
          receiverName: receiverName,
          callType: CallType.video,
        );
      }

      _isInCall = true;
      _callStatusStream.add(true);
      _messageStream.add('call_initiated');
    } catch (e) {
      _callStatusStream.addError('Failed to initiate call: $e');
      rethrow;
    }
  }

  /// Accept an incoming call
  Future<void> acceptCall() async {
    try {
      await _videoCallingService?.acceptCall();
      _isInCall = true;
      _callStatusStream.add(true);
      _messageStream.add('call_accepted');
    } catch (e) {
      _callStatusStream.addError('Failed to accept call: $e');
      rethrow;
    }
  }

  /// Reject an incoming call
  Future<void> rejectCall() async {
    try {
      await _videoCallingService?.rejectCall();
      _isInCall = false;
      _callStatusStream.add(false);
      _messageStream.add('call_rejected');
    } catch (e) {
      rethrow;
    }
  }

  /// End the current call
  Future<void> endCall() async {
    try {
      await _videoCallingService?.endCall();
      _isInCall = false;
      _callStatusStream.add(false);
      _messageStream.add('call_ended');
    } catch (e) {
      _callStatusStream.addError('Failed to end call: $e');
      rethrow;
    }
  }

  /// Check if currently in a call
  bool get isInCall => _isInCall;

  /// Cleanup resources
  void dispose() {
    _callStatusStream.close();
    _messageStream.close();
  }
}
