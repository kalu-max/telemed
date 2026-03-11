import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'video_call_service.dart';

class DoctorVideoCallScreen extends StatefulWidget {
  final DoctorVideoCallService callService;
  final String patientId;
  final String patientName;
  final bool isIncoming;

  const DoctorVideoCallScreen({
    super.key,
    required this.callService,
    required this.patientId,
    required this.patientName,
    this.isIncoming = false,
  });

  @override
  State<DoctorVideoCallScreen> createState() => _DoctorVideoCallScreenState();
}

class _DoctorVideoCallScreenState extends State<DoctorVideoCallScreen> {
  @override
  void initState() {
    super.initState();
    widget.callService.addListener(_onCallStateChange);

    if (widget.isIncoming) {
      widget.callService.acceptCall();
    } else {
      widget.callService.initiateCall(widget.patientId, widget.patientName);
    }
  }

  void _onCallStateChange() {
    if (!mounted) return;
    setState(() {});
    if (widget.callService.callStatus == CallStatus.idle) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    widget.callService.removeListener(_onCallStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.callService;
    final status = service.callStatus;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (full screen)
            Positioned.fill(
              child: status == CallStatus.connected
                  ? RTCVideoView(
                      service.remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.person, size: 50, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.patientName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            status == CallStatus.ringing
                                ? 'Ringing...'
                                : status == CallStatus.connecting
                                    ? 'Connecting...'
                                    : 'Waiting...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(color: Colors.white),
                        ],
                      ),
                    ),
            ),

            // Local video (PiP)
            if (service.isVideoEnabled)
              Positioned(
                bottom: 120,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RTCVideoView(
                      service.localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        service.endCall();
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            widget.patientName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (status == CallStatus.connected)
                            Text(
                              service.callDuration,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (status == CallStatus.connected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 4),
                            Text('Live', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
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
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: service.isAudioEnabled ? Icons.mic : Icons.mic_off,
                      label: service.isAudioEnabled ? 'Mute' : 'Unmute',
                      isActive: !service.isAudioEnabled,
                      onPressed: service.toggleAudio,
                    ),
                    _buildControlButton(
                      icon: service.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                      label: service.isVideoEnabled ? 'Camera' : 'Camera Off',
                      isActive: !service.isVideoEnabled,
                      onPressed: service.toggleVideo,
                    ),
                    _buildControlButton(
                      icon: Icons.cameraswitch,
                      label: 'Flip',
                      onPressed: service.switchCamera,
                    ),
                    _buildControlButton(
                      icon: service.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                      label: service.isSpeakerOn ? 'Speaker' : 'Earpiece',
                      isActive: !service.isSpeakerOn,
                      onPressed: service.toggleSpeaker,
                    ),
                    _buildControlButton(
                      icon: Icons.call_end,
                      label: 'End',
                      backgroundColor: Colors.red,
                      onPressed: () {
                        service.endCall();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    Color? backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? (isActive ? Colors.white : Colors.white24),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
            ),
            iconSize: 28,
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
