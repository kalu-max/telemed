import 'package:flutter/material.dart';

/// Audio call screen for voice calling
class AudioCallScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String conversationId;

  const AudioCallScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.conversationId,
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  late DateTime _callStartTime;
  late Duration _callDuration;

  @override
  void initState() {
    super.initState();
    _callStartTime = DateTime.now();
    _callDuration = Duration.zero;
    
    // Update call duration every second
    Future.delayed(const Duration(seconds: 1), _updateCallDuration);
  }

  void _updateCallDuration() {
    if (mounted) {
      setState(() {
        _callDuration = DateTime.now().difference(_callStartTime);
      });
      Future.delayed(const Duration(seconds: 1), _updateCallDuration);
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _endCall() {
    Navigator.pop(context);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),

            // Main call info section
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Recipient avatar
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.teal[600],
                    ),
                    child: Center(
                      child: Text(
                        widget.recipientName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recipient name
                  Text(
                    widget.recipientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Call status and duration
                  Text(
                    _formatDuration(_callDuration),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // Control buttons
            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isMuted ? Colors.red : Colors.grey[700],
                      ),
                      child: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),

                  // Speaker button
                  GestureDetector(
                    onTap: _toggleSpeaker,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSpeakerOn ? Colors.grey[700] : Colors.red,
                      ),
                      child: Icon(
                        _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),

                  // End call button
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
