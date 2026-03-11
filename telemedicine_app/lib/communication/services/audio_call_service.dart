import 'dart:async';
import 'video_calling_service.dart';
import '../models/call_model.dart';

/// Audio call service that delegates to VideoCallingService with audio-only mode
class AudioCallService {
  VideoCallingService? _videoCallingService;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  final StreamController<bool> _callStatusStream = StreamController.broadcast();
  final StreamController<String> _messageStream = StreamController.broadcast();

  Stream<bool> get callStatusStream => _callStatusStream.stream;
  Stream<String> get messageStream => _messageStream.stream;

  /// Initialize the audio call service
  Future<void> initialize({
    required String userId,
    required String userName,
    VideoCallingService? videoCallingService,
  }) async {
    _videoCallingService = videoCallingService;
  }

  /// Initiate an audio call via WebRTC (audio-only)
  Future<void> initiateAudioCall({
    required String receiverId,
    required String receiverName,
  }) async {
    try {
      if (_videoCallingService != null) {
        await _videoCallingService!.initiateVideoCall(
          receiverId: receiverId,
          receiverName: receiverName,
          callType: CallType.audio,
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

  /// Accept an incoming audio call
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

  /// Reject an incoming audio call
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

  /// Mute the audio
  Future<void> muteAudio() async {
    try {
      final localStream = _videoCallingService?.localRenderer.srcObject;
      if (localStream != null) {
        for (final track in localStream.getAudioTracks()) {
          track.enabled = false;
        }
      }
      _isMuted = true;
      _messageStream.add('audio_muted');
    } catch (e) {
      _callStatusStream.addError('Failed to mute audio: $e');
      rethrow;
    }
  }

  /// Unmute the audio
  Future<void> unmuteAudio() async {
    try {
      final localStream = _videoCallingService?.localRenderer.srcObject;
      if (localStream != null) {
        for (final track in localStream.getAudioTracks()) {
          track.enabled = true;
        }
      }
      _isMuted = false;
      _messageStream.add('audio_unmuted');
    } catch (e) {
      _callStatusStream.addError('Failed to unmute audio: $e');
      rethrow;
    }
  }

  /// Enable speaker
  Future<void> enableSpeaker() async {
    try {
      _isSpeakerOn = true;
      _messageStream.add('speaker_enabled');
    } catch (e) {
      rethrow;
    }
  }

  /// Disable speaker
  Future<void> disableSpeaker() async {
    try {
      _isSpeakerOn = false;
      _messageStream.add('speaker_disabled');
    } catch (e) {
      rethrow;
    }
  }

  /// End the current audio call
  Future<void> endCall() async {
    try {
      await _videoCallingService?.endCall();
      _isInCall = false;
      _isMuted = false;
      _callStatusStream.add(false);
      _messageStream.add('call_ended');
    } catch (e) {
      _callStatusStream.addError('Failed to end call: $e');
      rethrow;
    }
  }

  /// Check if currently in a call
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  /// Dispose the service
  void dispose() {
    _callStatusStream.close();
    _messageStream.close();
  }
}
