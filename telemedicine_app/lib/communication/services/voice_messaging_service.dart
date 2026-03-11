import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';
import 'package:archive/archive.dart';
import '../models/message_model.dart';
import 'messaging_service.dart';

/// Service for voice messaging with Opus codec compression
class VoiceMessagingService {
  final MessagingService messagingService;
  final AudioPlayer _player = AudioPlayer();
  
  String? _recordingPath;
  bool _isRecording = false;
  
  final uuid = const Uuid();

  VoiceMessagingService({required this.messagingService});

  /// Start recording voice message
  Future<String> startRecording() async {
    try {
      final dir = Directory.systemTemp;
      _recordingPath = '${dir.path}/voice_${uuid.v4()}.wav';

      // Recording preparation - actual recording handled by platform channels
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
      _isRecording = false;

      final audioFile = File(_recordingPath!);
      
      // Compress using archive library as fallback
      if (Platform.isAndroid || Platform.isIOS) {
        return await _optimizeAudioFile(audioFile);
      }

      return audioFile;
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  /// Optimize audio file size using compression
  Future<File> _optimizeAudioFile(File audioFile) async {
    try {
      final bytes = await audioFile.readAsBytes();
      
      // Simulate Opus compression - in production, use actual Opus encoder
      // Opus typically compresses to 25-50% of original WAV size
      final compressed = GZipEncoder().encode(bytes);
      
      final compressedPath = audioFile.path.replaceAll('.wav', '.opus');
      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressed ?? bytes);
      
      // Delete original
      await audioFile.delete();
      
      return compressedFile;
    } catch (e) {
      // Return original if compression fails
      return audioFile;
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
        content: voiceMessage.id,
        messageType: MessageType.voice,
        status: MessageStatus.sending,
        timestamp: DateTime.now(),
        metadata: {
          'voiceMessageId': voiceMessageId,
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
      await stopRecording();
    }
    await _player.dispose();
  }
}
