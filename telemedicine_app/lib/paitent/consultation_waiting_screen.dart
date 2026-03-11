import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import '../communication/widgets/call_widgets.dart' as call_widgets;

/// Shown after patient books a consultation.
/// Counts down 60 seconds — polls appointment status every 5 s.
/// When backend marks status as 'connected' or 'in-progress' (doctor accepted),
/// navigates to the video call. If the timer expires, shows a "try later" notice.
class ConsultationWaitingScreen extends StatefulWidget {
  final String appointmentId;
  final String doctorId;
  final String doctorName;
  final String specialty;
  final TeleMedicineApiClient api;

  const ConsultationWaitingScreen({
    super.key,
    required this.appointmentId,
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.api,
  });

  @override
  State<ConsultationWaitingScreen> createState() => _ConsultationWaitingScreenState();
}

class _ConsultationWaitingScreenState extends State<ConsultationWaitingScreen>
    with TickerProviderStateMixin {
  static const int _totalSeconds = 60;
  int _remaining = _totalSeconds;
  Timer? _countdownTimer;
  Timer? _pollTimer;
  bool _doctorConnected = false;
  bool _cancelled = false;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _startCountdown();
    _startPolling();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _pollTimer?.cancel();
        if (!_doctorConnected && !_cancelled) _onTimeout();
      }
    });
  }

  void _startPolling() {
    // Check immediately, then every 5 seconds
    _checkAppointmentStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkAppointmentStatus();
    });
  }

  Future<void> _checkAppointmentStatus() async {
    if (_doctorConnected || _cancelled || !mounted) return;
    final resp = await widget.api.getAppointments();
    if (!mounted || _doctorConnected || _cancelled) return;
    if (resp.success && resp.data != null) {
      for (final appt in resp.data!) {
        final id = appt['appointmentId']?.toString() ?? appt['id']?.toString() ?? '';
        if (id == widget.appointmentId) {
          final status = appt['status']?.toString() ?? '';
          if (status == 'connected' || status == 'in-progress') {
            _onDoctorConnected();
          }
          break;
        }
      }
    }
  }

  void _onDoctorConnected() {
    if (_doctorConnected) return;
    _doctorConnected = true;
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => call_widgets.VideoCallScreen(
          recipientId: widget.doctorId,
          recipientName: widget.doctorName,
          conversationId: widget.appointmentId,
        ),
      ),
    );
  }

  void _onTimeout() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Doctor Unavailable'),
        content: const Text(
          'The doctor didn\'t connect within 60 seconds. '
          'Your appointment has been saved — they may reach out to you shortly.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.pop(context); // back to find specialist
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelConsultation() async {
    _cancelled = true;
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    await widget.api.updateAppointmentStatus(widget.appointmentId, 'cancelled');
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / _totalSeconds;
    final isUrgent = _remaining <= 15;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelConsultation();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Doctor avatar + pulse ring
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) {
                    final scale = 1.0 + _pulseController.value * 0.12;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal[700],
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withAlpha(80),
                              blurRadius: 20 + _pulseController.value * 12,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.videocam, size: 48, color: Colors.white),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  'Connecting to',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.doctorName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  widget.specialty,
                  style: TextStyle(color: Colors.teal[700], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 40),
                // Countdown ring
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[200],
                        color: isUrgent ? Colors.orange : Colors.teal[700],
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_remaining',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: isUrgent ? Colors.orange : Colors.teal[700],
                            ),
                          ),
                          Text(
                            'seconds',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The doctor has been notified and will join shortly.',
                          style: TextStyle(color: Colors.blue[800], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('Cancel Consultation',
                      style: TextStyle(color: Colors.red)),
                  onPressed: _cancelConsultation,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
