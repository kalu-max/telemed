import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../communication/providers/communication_providers.dart';
import '../communication/models/call_model.dart';
import '../communication/widgets/chat_widgets.dart';

class ActiveConsultationScreen extends StatelessWidget {
  final String doctorName;
  final String specialty;
  final String? doctorId;

  const ActiveConsultationScreen({
    super.key,
    required this.doctorName,
    required this.specialty,
    this.doctorId,
  });

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.flip_camera_ios),
              title: const Text('Switch Camera'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Camera switched')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.screen_share),
              title: const Text('Share Screen'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Screen sharing not supported on this device')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined),
              title: const Text('Report Issue'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Issue reported. Thank you.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_end, color: Colors.red),
              title: const Text('End Call', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Main Background (Doctor's Video Feed)
          // Use real WebRTC remote video when available, fallback to avatar
          Consumer<VideoCallingProvider>(
            builder: (context, videoProvider, _) {
              final service = videoProvider.videoCallingService;
              final isConnected = videoProvider.currentCall?.status == CallStatus.connected;

              if (isConnected) {
                return RTCVideoView(
                  service.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                );
              }

              return Container(
                color: Colors.grey[900],
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.teal[700],
                        child: Text(
                          doctorName.isNotEmpty ? doctorName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        doctorName,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isConnected ? 'Connected' : 'Connecting...',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Gradient overlay at the bottom for text readability
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withAlpha(204), Colors.transparent],
                ),
              ),
            ),
          ),

          // 2. Top Controls (REC, Timer, Options)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // REC Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'REC',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '04:23',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      // More Options
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            size: 18,
                            color: Colors.black,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => _showOptionsSheet(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. User PiP (Picture-in-Picture) Camera - real local video
          Positioned(
            top: 80,
            right: 16,
            child: Consumer<VideoCallingProvider>(
              builder: (context, videoProvider, _) {
                final service = videoProvider.videoCallingService;
                return Container(
                  width: 100,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RTCVideoView(
                    service.localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                );
              },
            ),
          ),

          // 4. Doctor Info and Bottom Control Bar
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$specialty • Online',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Control Buttons Container
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        Icons.mic_none,
                        'Mute',
                        onPressed: () {},
                      ),
                      _buildControlButton(
                        Icons.videocam,
                        'Video',
                        onPressed: () {},
                      ),
                      // End Call Button (Red)
                      GestureDetector(
                        onTap: () =>
                            Navigator.pop(context), // Ends call and goes back
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      _buildControlButton(
                        Icons.chat_bubble_outline,
                        'Chat',
                        hasNotification: true,
                        onPressed: () {
                          final convId = 'consult-${doctorId ?? 'unknown'}';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: convId,
                                participantId: doctorId ?? '',
                                participantName: doctorName,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildControlButton(
                        Icons.volume_up,
                        'Audio',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String label, {
    bool hasNotification = false,
    VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: Colors.black87, size: 28),
              if (hasNotification)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
