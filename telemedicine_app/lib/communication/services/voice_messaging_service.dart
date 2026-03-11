import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import 'messaging_service.dart';

/// Service for voice messaging with Opus codec compression
class VoiceMessagingService {
  final MessagingService messagingService;
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();

  String? _recordingPath;
  bool _isRecording = false;

  final uuid = const Uuid();

  VoiceMessagingService({required this.messagingService});

  /// Start recording voice message
  Future<String> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      final dir = Directory.systemTemp;
      _recordingPath = '${dir.path}/voice_${uuid.v4()}.opus';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.opus,
          bitRate: 24000,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: _recordingPath!,
      );

      _isRecording = true;
      return _recordingPath!;
    } catch (e) {
      throw Exception('Failed to start recording: $e');
    }
  }

  /// Stop recording and get the audio file
  Future<File> stopRecording() async {
    try {
      if (_recordingPath == null) {
        throw Exception('No recording in progress');
      }

      final resolvedPath = await _recorder.stop();
      _isRecording = false;

      final outputPath = resolvedPath ?? _recordingPath;
      if (outputPath == null || outputPath.isEmpty) {
        throw Exception('Recording did not produce an audio file');
      }

      final audioFile = File(outputPath);
      if (!await audioFile.exists()) {
        throw Exception('Recorded audio file could not be found');
      }

      _recordingPath = audioFile.path;
      return audioFile;
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  /// Send voice message
  Future<VoiceMessage> sendVoiceMessage({
    required String conversationId,
    required String receiverId,
    required String receiverName,
    required File audioFile,
  }) async {
    try {
      final voiceMessageId = uuid.v4();
      final audioBytes = await audioFile.readAsBytes();
      final fileSize = audioBytes.length;

      // Calculate duration from audio metadata
      // In production, use proper audio analysis library
      final duration = Duration(
        milliseconds: (fileSize / 2 / 16000 * 1000).toInt(), // rough estimate
      );

      final voiceMessage = VoiceMessage(
        id: voiceMessageId,
        messageId: uuid.v4(),
        audioPath: audioFile.path,
        duration: duration,
        fileSize: fileSize,
        codec: 'opus',
        bitrate: 24000, // 24 kbps Opus
        waveformData: '', // Will be generated on UI side
      );

      // Create chat message
      final chatMessage = ChatMessage(
        id: voiceMessage.messageId,
        conversationId: conversationId,
        senderId: messagingService.userId,
        senderName: messagingService.userName,
        receiverId: receiverId,
        content: 'Voice message',
        messageType: MessageType.voice,
        status: MessageStatus.sending,
        timestamp: DateTime.now(),
        metadata: {
          'messageType': 'voice',
          'voiceMessageId': voiceMessageId,
          'audioPath': voiceMessage.audioPath,
          'duration': duration.inMilliseconds,
          'fileSize': fileSize,
          'codec': 'opus',
          'bitrate': 24000,
        },
      );

      // Emit voice message via socket
      messagingService.socket.emit('sendVoiceMessage', {
        'messageId': chatMessage.id,
        'conversationId': conversationId,
        'senderId': messagingService.userId,
        'senderName': messagingService.userName,
        'receiverId': receiverId,
        'audioData': _encodeAudioForTransmission(audioBytes),
        'duration': duration.inMilliseconds,
        'fileSize': fileSize,
        'codec': 'opus',
        'bitrate': 24000,
      });

      return voiceMessage;
    } catch (e) {
      throw Exception('Failed to send voice message: $e');
    }
  }

  /// Encode audio for network transmission
  String _encodeAudioForTransmission(Uint8List audioBytes) {
    // In production, encode to base64 for JSON transmission
    // or use binary protocol for efficiency
    return base64Encode(audioBytes);
  }

  /// Play voice message
  Future<void> playVoiceMessage(String audioPath) async {
    try {
      final source = DeviceFileSource(audioPath);
      await _player.play(source, volume: 1.0);
    } catch (e) {
      throw Exception('Failed to play voice message: $e');
    }
  }

  /// Pause voice message playback
  Future<void> pauseVoiceMessage() async {
    await _player.pause();
  }

  /// Resume voice message playback
  Future<void> resumeVoiceMessage() async {
    await _player.resume();
  }

  /// Stop voice message playback
  Future<void> stopVoiceMessage() async {
    await _player.stop();
  }

  /// Get playback state stream
  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;

  /// Get playback position stream
  Stream<Duration> get positionStream => _player.onPositionChanged;

  /// Is currently recording
  bool get isRecording => _isRecording;

  /// Is currently playing
  Future<bool> get isPlaying async {
    final state = _player.state;
    return state == PlayerState.playing;
  }

  /// Cleanup
  Future<void> dispose() async {
    if (_isRecording) {
      await _recorder.cancel();
    }
    await _player.dispose();
    await _recorder.dispose();
  }
}
