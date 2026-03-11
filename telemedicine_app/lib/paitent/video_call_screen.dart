import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'video_call_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String remoteUserId;
  final String remoteUserName;
  final String? remoteUserAvatar;

  const VideoCallScreen({
    super.key,
    required this.remoteUserId,
    required this.remoteUserName,
    required this.remoteUserAvatar,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late VideoCallService _callService;
  bool _showQualityPanel = false;
  Duration _callDuration = Duration.zero;
  late Stopwatch _stopwatch;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _callService = VideoCallService();

    _callService.initiateCall(
      widget.remoteUserId,
      widget.remoteUserName,
      widget.remoteUserAvatar,
    );

    _callService.addListener(_onServiceUpdate);
    _stopwatch.start();
    _startTimerUpdate();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _startTimerUpdate() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_stopwatch.isRunning && mounted) {
        setState(() {
          _callDuration = _stopwatch.elapsed;
        });
        _startTimerUpdate();
      }
    });
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _callService.removeListener(_onServiceUpdate);
    try {
      _callService.dispose();
    } catch (e) {
      // Service already disposed, ignore
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text(widget.remoteUserName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onEndCall,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
            child: Center(
              child: Text(
                _formatDuration(_callDuration),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildVideoArea(),
          _buildNetworkIndicator(),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildCallControls(),
          ),
          if (_showQualityPanel) _buildQualityPanel(),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    final realService = _callService.realService;
    return Container(
      color: Colors.grey[900],
      child: Stack(
        children: [
          // Remote video — full screen real WebRTC feed
          Positioned.fill(
            child: RTCVideoView(
              realService.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              placeholderBuilder: (context) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[800],
                      child: const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.remoteUserName,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _callService.callStatus == CallStatus.connected ? 'Connected' : _callService.callStatus.name.toUpperCase(),
                      style: TextStyle(
                        color: _callService.callStatus == CallStatus.connected ? Colors.green : Colors.orange,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Local video — picture-in-picture
          Positioned(
            bottom: 80,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RTCVideoView(
                  realService.localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkIndicator() {
    final quality = _callService.callStatus == CallStatus.connected ? 'Connected' : 'Connecting';
    final color = _callService.callStatus == CallStatus.connected ? Colors.green : Colors.orange;

    return Positioned(
      top: 16,
      right: 16,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showQualityPanel = !_showQualityPanel;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
            color: color.withAlpha(51),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.signal_cellular_4_bar, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                quality,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallControls() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: _callService,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _callService.callStatus == CallStatus.connected
                        ? 'WebRTC - ${_callService.callStatus.name}'
                        : _callService.callStatus.name.toUpperCase(),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: _callService.isAudioEnabled
                          ? Icons.mic
                          : Icons.mic_off,
                      label: 'Mute',
                      onPressed: _callService.toggleAudio,
                      backgroundColor: Colors.grey[700],
                    ),
                    _buildControlButton(
                      icon: _callService.isVideoEnabled
                          ? Icons.videocam
                          : Icons.videocam_off,
                      label: 'Video',
                      onPressed: _callService.toggleVideo,
                      backgroundColor: Colors.grey[700],
                    ),
                    _buildControlButton(
                      icon: Icons.flip_to_back,
                      label: 'Flip',
                      onPressed: () => _callService.switchCamera(),
                      backgroundColor: Colors.grey[700],
                    ),
                    _buildControlButton(
                      icon: _callService.isSpeakerEnabled
                          ? Icons.volume_up
                          : Icons.volume_off,
                      label: 'Speaker',
                      onPressed: _callService.toggleSpeaker,
                      backgroundColor: Colors.grey[700],
                    ),
                    _buildControlButton(
                      icon: Icons.call_end,
                      label: 'End',
                      onPressed: _onEndCall,
                      backgroundColor: Colors.red[700],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color? backgroundColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildQualityPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Network Quality',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() => _showQualityPanel = false);
                  },
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            _buildStatRow('Status', _callService.callStatus.name),
            _buildStatRow('Duration', _formatDuration(_callDuration)),
            _buildStatRow('Audio', _callService.isAudioEnabled ? 'On' : 'Muted'),
            _buildStatRow('Video', _callService.isVideoEnabled ? 'On' : 'Off'),
            const SizedBox(height: 12),
            const Text(
              'Quality adapts automatically based on network.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _onEndCall() {
    Navigator.pop(context);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
