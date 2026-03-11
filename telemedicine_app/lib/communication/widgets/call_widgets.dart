import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/message_model.dart';
import '../models/call_model.dart';
import '../providers/communication_providers.dart';

/// Voice message UI widget with recording and playback
class VoiceMessageWidget extends StatefulWidget {
  final VoiceMessage voiceMessage;
  final bool isOwn;

  const VoiceMessageWidget({
    super.key,
    required this.voiceMessage,
    required this.isOwn,
  });

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  late VoiceMessagingProvider _voiceProvider;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _voiceProvider = context.read<VoiceMessagingProvider>();
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _voiceProvider.pausePlayback();
    } else {
      _voiceProvider.playVoiceMessage(widget.voiceMessage.audioPath);
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isOwn ? Colors.teal[600] : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isOwn ? Colors.white : Colors.teal[600],
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isOwn ? Colors.teal[600] : Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer<VoiceMessagingProvider>(
                  builder: (context, provider, _) {
                    final position = provider.currentPosition;
                    final fileSize =
                        '${(widget.voiceMessage.fileSize / 1000).toStringAsFixed(1)} KB';

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${position.inSeconds}s / ${widget.voiceMessage.duration.inSeconds}s',
                          style: TextStyle(
                            color: widget.isOwn ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Opus • $fileSize',
                          style: TextStyle(
                            color: widget.isOwn ? Colors.white70 : Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: widget.voiceMessage.duration.inSeconds > 0
                        ? (context
                                .watch<VoiceMessagingProvider>()
                                .currentPosition
                                .inMilliseconds /
                            widget.voiceMessage.duration.inMilliseconds)
                        : 0,
                    minHeight: 2,
                    backgroundColor: widget.isOwn ? Colors.white30 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isOwn ? Colors.white : Colors.teal[600]!,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Voice recorder widget for sending voice messages
class VoiceRecorderWidget extends StatefulWidget {
  final String conversationId;
  final String receiverId;
  final String receiverName;

  const VoiceRecorderWidget({
    super.key,
    required this.conversationId,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  late VoiceMessagingProvider _voiceProvider;
  Duration _recordingDuration = Duration.zero;
  late Timer _recordingTimer;

  @override
  void initState() {
    super.initState();
    _voiceProvider = context.read<VoiceMessagingProvider>();
  }

  void _startRecording() async {
    try {
      await _voiceProvider.startRecording();
      if (!mounted) return;
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        setState(() {
          _recordingDuration += const Duration(milliseconds: 100);
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _stopRecording() async {
    try {
      _recordingTimer.cancel();
      await _voiceProvider.stopRecording();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _VoicePreviewDialog(
            conversationId: widget.conversationId,
            receiverId: widget.receiverId,
            receiverName: widget.receiverName,
            duration: _recordingDuration,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _recordingDuration = Duration.zero;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = context.watch<VoiceMessagingProvider>().isRecording;

    if (!isRecording) {
      return IconButton(
        icon: const Icon(Icons.mic),
        onPressed: _startRecording,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[200]!),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.red[600], size: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recording...',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.red[600]),
            onPressed: _stopRecording,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (context.read<VoiceMessagingProvider>().isRecording) {
      _recordingTimer.cancel();
    }
    super.dispose();
  }
}

/// Voice preview dialog
class _VoicePreviewDialog extends StatelessWidget {
  final String conversationId;
  final String receiverId;
  final String receiverName;
  final Duration duration;

  const _VoicePreviewDialog({
    required this.conversationId,
    required this.receiverId,
    required this.receiverName,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send voice message?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic,
            size: 48,
            color: Colors.teal[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Duration: ${duration.inSeconds}s',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Send voice message
            Navigator.pop(context);
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}

/// Video call screen with real WebRTC video rendering
class VideoCallScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String conversationId;

  const VideoCallScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.conversationId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isAudioMuted = false;
  bool _isVideoOff = false;
  bool _isInitializing = true;
  bool _isFrontCamera = true;
  String? _errorMessage;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      final videoProvider = context.read<VideoCallingProvider>();
      await videoProvider.initiateVideoCall(
        receiverId: widget.recipientId,
        receiverName: widget.recipientName,
      );
      if (mounted) {
        setState(() => _isInitializing = false);
        _startDurationTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Failed to start call: $e';
        });
      }
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDuration += const Duration(seconds: 1));
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _toggleAudio() {
    final service = context.read<VideoCallingProvider>().videoCallingService;
    final localStream = service.localRenderer.srcObject;
    if (localStream != null) {
      for (final track in localStream.getAudioTracks()) {
        track.enabled = _isAudioMuted;
      }
    }
    setState(() => _isAudioMuted = !_isAudioMuted);
  }

  void _toggleVideo() {
    final service = context.read<VideoCallingProvider>().videoCallingService;
    final localStream = service.localRenderer.srcObject;
    if (localStream != null) {
      for (final track in localStream.getVideoTracks()) {
        track.enabled = _isVideoOff;
      }
    }
    setState(() => _isVideoOff = !_isVideoOff);
  }

  void _switchCamera() {
    final service = context.read<VideoCallingProvider>().videoCallingService;
    final localStream = service.localRenderer.srcObject;
    if (localStream != null) {
      final videoTrack = localStream.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        Helper.switchCamera(videoTrack);
        setState(() => _isFrontCamera = !_isFrontCamera);
      }
    }
  }

  Future<void> _endCall() async {
    try {
      await context.read<VideoCallingProvider>().endCall();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.teal),
              const SizedBox(height: 24),
              Text(
                'Connecting to ${widget.recipientName}...',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<VideoCallingProvider>(
        builder: (context, videoProvider, _) {
          final service = videoProvider.videoCallingService;
          final callStatus = videoProvider.currentCall?.status;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Remote video (full screen)
              RTCVideoView(
                service.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                placeholderBuilder: (_) => Container(
                  color: Colors.grey[900],
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.teal[700],
                          child: Text(
                            widget.recipientName.isNotEmpty
                                ? widget.recipientName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 36,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.recipientName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _callStatusText(callStatus),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Local video (picture-in-picture)
              if (!_isVideoOff)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: _switchCamera,
                    child: Container(
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: RTCVideoView(
                        service.localRenderer,
                        mirror: _isFrontCamera,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),

              // Top bar with call info
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: callStatus == CallStatus.connected
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(_callDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Network quality indicator
                      if (videoProvider.lastStats != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _qualityIcon(videoProvider.currentVideoQuality),
                                  color: _qualityColor(videoProvider.currentVideoQuality),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  videoProvider.currentVideoQuality.name.toUpperCase(),
                                  style: TextStyle(
                                    color: _qualityColor(videoProvider.currentVideoQuality),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Bottom controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: 20,
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    left: 24,
                    right: 24,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: _isAudioMuted ? Icons.mic_off : Icons.mic,
                        label: _isAudioMuted ? 'Unmute' : 'Mute',
                        isActive: !_isAudioMuted,
                        onPressed: _toggleAudio,
                      ),
                      _buildControlButton(
                        icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                        label: _isVideoOff ? 'Start Video' : 'Stop Video',
                        isActive: !_isVideoOff,
                        onPressed: _toggleVideo,
                      ),
                      _buildControlButton(
                        icon: Icons.cameraswitch,
                        label: 'Flip',
                        isActive: true,
                        onPressed: _switchCamera,
                      ),
                      _buildControlButton(
                        icon: Icons.call_end,
                        label: 'End',
                        isActive: false,
                        isEndCall: true,
                        onPressed: _endCall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _callStatusText(CallStatus? status) {
    switch (status) {
      case CallStatus.initiating:
        return 'Initiating...';
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.connecting:
        return 'Connecting...';
      case CallStatus.connected:
        return 'Connected';
      case CallStatus.disconnected:
        return 'Disconnected';
      case null:
        return 'Waiting...';
      default:
        return status.name;
    }
  }

  IconData _qualityIcon(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.high:
        return Icons.signal_cellular_4_bar;
      case VideoQuality.medium:
        return Icons.signal_cellular_alt_2_bar;
      case VideoQuality.low:
        return Icons.signal_cellular_alt_1_bar;
    }
  }

  Color _qualityColor(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.high:
        return Colors.green;
      case VideoQuality.medium:
        return Colors.orange;
      case VideoQuality.low:
        return Colors.red;
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    bool isEndCall = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: label,
          onPressed: onPressed,
          backgroundColor: isEndCall
              ? Colors.red
              : isActive
                  ? Colors.white24
                  : Colors.white.withValues(alpha: 0.15),
          elevation: 0,
          mini: !isEndCall,
          child: Icon(
            icon,
            color: isEndCall ? Colors.white : (isActive ? Colors.white : Colors.white54),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
