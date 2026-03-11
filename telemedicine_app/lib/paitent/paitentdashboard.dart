import 'package:flutter/material.dart';
import 'under_process.dart';
import 'profile.dart';
import 'user_model.dart';
import 'api_client.dart';
import 'notifications.dart';
import 'calendar.dart';
import 'chat_list.dart';
import 'consultation_history_screen.dart';
import '../communication/widgets/call_widgets.dart' as web;

class PatientDashboard extends StatefulWidget {
  final UserProfile? userProfile;
  final TeleMedicineApiClient? api;
  final String? userId;

  const PatientDashboard({super.key, this.userProfile, this.api, this.userId});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _selectedIndex = 0; // State for bottom navigation
  List<Map<String, dynamic>> _metrics = [];
  bool _loadingMetrics = true;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (widget.api == null) return;
    final resp = await widget.api!.getAppointments();
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      setState(() => _appointments = resp.data!);
    }
  }

  Future<void> _loadMetrics() async {
    if (widget.api == null || widget.userId == null || widget.userId!.isEmpty) {
      setState(() {
        _metrics = [];
        _loadingMetrics = false;
      });
      return;
    }
    setState(() {
      _loadingMetrics = true;
    });
    final resp = await widget.api!.getPatientMetrics(widget.userId!);
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      setState(() {
        _metrics = resp.data!;
        _loadingMetrics = false;
      });
    } else {
      setState(() {
        _metrics = [];
        _loadingMetrics = false;
      });
    }
  }

  void _showRescheduleDialog(Map<String, dynamic> appt) {
    final appointmentId =
        appt['appointmentId']?.toString() ?? appt['id']?.toString() ?? '';
    DateTime? newDate;
    TimeOfDay? newTime;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Reschedule Appointment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doctor: ${appt['doctorName'] ?? appt['doctorId'] ?? 'Doctor'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      newDate == null
                          ? 'Pick Date'
                          : '${newDate!.day}/${newDate!.month}/${newDate!.year}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(
                          const Duration(days: 1),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setDialogState(() => newDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      newTime == null ? 'Pick Time' : newTime!.format(ctx),
                    ),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => newTime = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      (isLoading ||
                          newDate == null ||
                          newTime == null ||
                          appointmentId.isEmpty)
                      ? null
                      : () async {
                          setDialogState(() => isLoading = true);
                          final slotTime = DateTime(
                            newDate!.year,
                            newDate!.month,
                            newDate!.day,
                            newTime!.hour,
                            newTime!.minute,
                          );
                          final resp = await widget.api!
                              .updateAppointmentStatus(
                                appointmentId,
                                'rescheduled',
                              );
                          if (resp.success && widget.api != null) {
                            await widget.api!.bookAppointment(
                              doctorId: appt['doctorId']?.toString() ?? '',
                              slotTime: slotTime,
                              reason:
                                  appt['reason']?.toString() ??
                                  'Rescheduled consultation',
                            );
                          }
                          setDialogState(() => isLoading = false);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadAppointments();
                          final success = resp.success;
                          final msg = success
                              ? 'Appointment rescheduled'
                              : (resp.error ?? 'Could not reschedule');
                          final color = success ? Colors.green : Colors.red;
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: color,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirm',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Very light grey background
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildStatusBadge(),
                const SizedBox(height: 32),

                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildQuickActions(),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Upcoming Appointment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CalendarScreen(api: widget.api!),
                          ),
                        );
                      },
                      child: const Text(
                        'See all',
                        style: TextStyle(color: Colors.teal),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildUpcomingAppointmentCard(),
                const SizedBox(height: 32),

                const Text(
                  'Recent Health Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildHealthMetrics(),
                const SizedBox(height: 20), // Extra padding at bottom
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // --- Widget Builders for modularity ---

  Widget _buildHeader() {
    final userName = widget.userProfile?.name ?? 'Patient';
    final userInitial = userName.isNotEmpty
        ? userName.characters.first.toUpperCase()
        : 'P';

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.blue,
          child: Text(
            userInitial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${userName.split(' ').first}!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Welcome back to MediCare',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationsScreen(api: widget.api!),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 10),
              ],
            ),
            child: const Icon(Icons.notifications_none, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
          const Text(
            'Status: Stable',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _quickActionCard(
            Icons.videocam,
            'Video\nCall',
            isPrimary: true,
            onTap: _startUpcomingAppointmentVideoCall,
          ),
          const SizedBox(width: 16),
          _quickActionCard(
            Icons.calendar_month,
            'Book\nAppt',
            onTap: () => Navigator.pushNamed(context, '/search'),
          ),
          const SizedBox(width: 16),
          _quickActionCard(
            Icons.receipt_long,
            'View\nPrescriptions',
            onTap: () => Navigator.pushNamed(context, '/prescription'),
          ),
          const SizedBox(width: 16),
          _quickActionCard(
            Icons.description,
            'Lab\nResults',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _LabResultsScreen(api: widget.api),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _quickActionCard(
            Icons.history,
            'History',
            onTap: () {
              if (widget.api != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConsultationHistoryScreen(api: widget.api!),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard(
    IconData icon,
    String title, {
    bool isPrimary = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.teal[700] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(26),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPrimary ? Colors.teal[600] : Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : Colors.teal[700],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: isPrimary ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAppointmentCard() {
    // Find the soonest scheduled/pending appointment
    final upcoming =
        _appointments.where((a) {
          final s = a['status']?.toString() ?? '';
          return s == 'scheduled' || s == 'pending';
        }).toList()..sort((a, b) {
          final da =
              DateTime.tryParse(a['slotTime']?.toString() ?? '') ??
              DateTime(2100);
          final db =
              DateTime.tryParse(b['slotTime']?.toString() ?? '') ??
              DateTime(2100);
          return da.compareTo(db);
        });

    if (upcoming.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(26),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.calendar_today, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No upcoming appointments',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
              ),
              onPressed: () => Navigator.pushNamed(context, '/search'),
              child: const Text(
                'Book Now',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final appt = upcoming.first;
    final doctorName =
        appt['doctorName']?.toString() ??
        appt['doctorId']?.toString() ??
        'Doctor';
    final reason = appt['reason']?.toString() ?? 'Consultation';
    final slotRaw = appt['slotTime'];
    final slotDt = slotRaw != null
        ? DateTime.tryParse(slotRaw.toString())
        : null;
    final isToday =
        slotDt != null &&
        slotDt.year == DateTime.now().year &&
        slotDt.month == DateTime.now().month &&
        slotDt.day == DateTime.now().day;
    final timeStr = slotDt != null
        ? '${slotDt.hour.toString().padLeft(2, '0')}:${slotDt.minute.toString().padLeft(2, '0')}'
        : '--:--';
    final dateLabel = isToday
        ? 'Today'
        : (slotDt != null ? '${slotDt.day}/${slotDt.month}' : 'Scheduled');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.teal[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person, color: Colors.teal[700], size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.videocam, size: 16, color: Colors.teal[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Video Consultation',
                          style: TextStyle(
                            color: Colors.teal[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isToday ? Colors.teal[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      dateLabel,
                      style: TextStyle(
                        color: isToday ? Colors.teal[700] : Colors.orange[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeStr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _showRescheduleDialog(appt);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Reschedule',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _joinAppointment(appt);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Join Now', style: TextStyle(color: Colors.white)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetrics() {
    if (_loadingMetrics) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_metrics.isEmpty) {
      // fallback to sample cards
      return Row(
        children: [
          Expanded(
            child: _metricCard(
              Icons.favorite,
              'Heart Rate',
              '98',
              'bpm',
              '+2% vs last week',
              Colors.red,
              isPositive: false,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _metricCard(
              Icons.water_drop,
              'Blood Pressure',
              '120/80',
              'mmHg',
              'Normal',
              Colors.blue,
              isPositive: true,
            ),
          ),
        ],
      );
    }

    // show up to two most recent metrics
    final m1 = _metrics.isNotEmpty ? _metrics[_metrics.length - 1] : null;
    final m2 = _metrics.length > 1 ? _metrics[_metrics.length - 2] : null;
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            Icons.insights,
            m1 != null ? (m1['metric']?.toString() ?? 'Metric') : 'Metric',
            m1 != null ? (m1['value']?.toString() ?? '') : '',
            '',
            m1 != null
                ? (DateTime.tryParse(
                        m1['timestamp']?.toString() ?? '',
                      )?.toLocal().toString() ??
                      '')
                : '',
            Colors.purple,
            isPositive: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _metricCard(
            Icons.health_and_safety,
            m2 != null ? (m2['metric']?.toString() ?? 'Metric') : 'Metric',
            m2 != null ? (m2['value']?.toString() ?? '') : '',
            '',
            m2 != null
                ? (DateTime.tryParse(
                        m2['timestamp']?.toString() ?? '',
                      )?.toLocal().toString() ??
                      '')
                : '',
            Colors.green,
            isPositive: true,
          ),
        ),
      ],
    );
  }

  Widget _metricCard(
    IconData icon,
    String title,
    String value,
    String unit,
    String subtitle,
    Color color, {
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPositive ? Icons.check_circle : Icons.trending_up,
                color: isPositive ? Colors.green : Colors.orange,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        if (index == 0) {
          setState(() => _selectedIndex = index);
        } else if (index == 3) {
          // Navigate to Profile screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                userProfile:
                    widget.userProfile ??
                    UserProfile(
                      name: 'Patient',
                      email: 'user@example.com',
                      phone: '+1 (555) 000-0000',
                      dateOfBirth: '01/01/1990',
                      gender: 'Male',
                      bloodType: 'O+',
                      address: 'Update your address',
                    ),
              ),
            ),
          );
        } else {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CalendarScreen(api: widget.api!),
              ),
            );
            return;
          }
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatListScreen(api: widget.api!),
              ),
            );
            return;
          }
          if (index == 3) {
            if (widget.userProfile != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfileScreen(userProfile: widget.userProfile!),
                ),
              );
            }
            return;
          }
          String title = 'Feature';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UnderProcessScreen(title: title),
            ),
          );
        }
      },
      selectedItemColor: Colors.teal[700],
      unselectedItemColor: Colors.grey[400],
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_rounded),
          label: 'Chat',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  Map<String, dynamic>? _getNextCallableAppointment() {
    final callableAppointments =
        _appointments.where((appointment) {
          final status = appointment['status']?.toString() ?? '';
          final doctorId = appointment['doctorId']?.toString() ?? '';
          return (status == 'scheduled' || status == 'pending') &&
              doctorId.isNotEmpty;
        }).toList()..sort((a, b) {
          final left =
              DateTime.tryParse(a['slotTime']?.toString() ?? '') ??
              DateTime(2100);
          final right =
              DateTime.tryParse(b['slotTime']?.toString() ?? '') ??
              DateTime(2100);
          return left.compareTo(right);
        });

    if (callableAppointments.isEmpty) {
      return null;
    }

    return callableAppointments.first;
  }

  void _startUpcomingAppointmentVideoCall() {
    final appointment = _getNextCallableAppointment();
    if (appointment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Book an appointment with a doctor to start a video call.',
          ),
        ),
      );
      Navigator.pushNamed(context, '/search');
      return;
    }

    _joinAppointment(appointment);
  }

  void _joinAppointment(Map<String, dynamic> appointment) {
    final doctorId = appointment['doctorId']?.toString() ?? '';
    if (doctorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This appointment is missing doctor details.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final doctorName = appointment['doctorName']?.toString() ?? 'Doctor';
    final appointmentId =
        appointment['appointmentId']?.toString() ??
        appointment['id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final conversationId = 'appointment-$appointmentId';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildVideoCallScreen(
          recipientId: doctorId,
          recipientName: doctorName,
          conversationId: conversationId,
        ),
      ),
    );
  }

  /// Build the unified video call screen (WebRTC on all platforms)
  Widget _buildVideoCallScreen({
    required String recipientId,
    required String recipientName,
    required String conversationId,
  }) {
    return web.VideoCallScreen(
      recipientId: recipientId,
      recipientName: recipientName,
      conversationId: conversationId,
    );
  }
}

// ---------------------------------------------------------------------------
// Lab Results Screen
// ---------------------------------------------------------------------------
class _LabResultsScreen extends StatefulWidget {
  final TeleMedicineApiClient? api;
  const _LabResultsScreen({this.api});

  @override
  State<_LabResultsScreen> createState() => _LabResultsScreenState();
}

class _LabResultsScreenState extends State<_LabResultsScreen> {
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    setState(() => _loading = true);
    if (widget.api == null) {
      setState(() {
        _loading = false;
        _results = [];
      });
      return;
    }
    try {
      // Reuse appointments endpoint and show completed ones as lab-linked records
      final resp = await widget.api!.getAppointments();
      if (resp.success && resp.data != null) {
        setState(() {
          _results = resp.data!
              .where((a) => a['status'] == 'completed')
              .toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = resp.error;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Results'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : _results.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 72,
                    color: Colors.teal[200],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No lab results on file',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Results from completed consultations will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final item = _results[index];
                final doctorName = item['doctorName']?.toString() ?? 'Doctor';
                final raw = item['slotTime'];
                final dt = raw != null
                    ? DateTime.tryParse(raw.toString())
                    : null;
                final dateStr = dt != null
                    ? '${dt.day}/${dt.month}/${dt.year}'
                    : 'Unknown date';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal[50],
                      child: Icon(Icons.science, color: Colors.teal[700]),
                    ),
                    title: Text(
                      item['reason']?.toString() ?? 'Consultation',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Dr. $doctorName  •  $dateStr'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
        onPressed: _fetchResults,
      ),
    );
  }
}
