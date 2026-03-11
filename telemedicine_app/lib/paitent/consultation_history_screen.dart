import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'api_client.dart';

/// Shows consultation history with a 7-day free-follow-up section.
///
/// Appointments completed within the last 7 days show a "Follow-up" badge and
/// allow the patient to upload test results directly from this screen.
/// Older appointments are listed as past consultations.
class ConsultationHistoryScreen extends StatefulWidget {
  final TeleMedicineApiClient api;

  const ConsultationHistoryScreen({super.key, required this.api});

  @override
  State<ConsultationHistoryScreen> createState() => _ConsultationHistoryScreenState();
}

class _ConsultationHistoryScreenState extends State<ConsultationHistoryScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _followUps = [];
  List<Map<String, dynamic>> _past = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final resp = await widget.api.getAppointments();
    if (!mounted) return;
    if (!resp.success || resp.data == null) {
      setState(() {
        _error = resp.error ?? 'Failed to load consultations';
        _loading = false;
      });
      return;
    }

    final now = DateTime.now();
    final completed = resp.data!.where((a) {
      final s = a['status']?.toString() ?? '';
      return s == 'completed' || s == 'connected' || s == 'in-progress';
    }).toList();

    final followUps = <Map<String, dynamic>>[];
    final past = <Map<String, dynamic>>[];

    for (final a in completed) {
      final raw = a['slotTime'] ?? a['createdAt'];
      final dt = raw != null ? DateTime.tryParse(raw.toString()) : null;
      if (dt != null && now.difference(dt).inDays <= 7) {
        followUps.add(a);
      } else {
        past.add(a);
      }
    }

    // also show scheduled/pending in past
    for (final a in resp.data!) {
      final s = a['status']?.toString() ?? '';
      if (s == 'scheduled' || s == 'pending' || s == 'cancelled') {
        past.add(a);
      }
    }

    setState(() {
      _followUps = followUps;
      _past = past;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        title: const Text('Consultations & History'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Follow-ups'),
                  if (_followUps.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        '${_followUps.length}',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'All History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFollowUpTab(),
                    _buildHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  // ── FOLLOW-UP TAB ─────────────────────────────────────────────────────────

  Widget _buildFollowUpTab() {
    if (_followUps.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available,
        title: 'No Active Follow-ups',
        subtitle: 'Consultations completed in the last 7 days will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(
          icon: Icons.info_outline,
          color: Colors.teal,
          text: '7-day free follow-up: You can upload test results, ask questions, or request routine checks within 7 days of your consultation.',
        ),
        const SizedBox(height: 16),
        ..._followUps.map((a) => _FollowUpCard(appt: a, api: widget.api)),
      ],
    );
  }

  // ── HISTORY TAB ───────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    final all = [..._followUps, ..._past];
    if (all.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No Consultations Yet',
        subtitle: 'Your consultation history will appear here once you have had an appointment.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: all.map((a) => _HistoryCard(appt: a)).toList(),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required MaterialColor color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[100]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color[700], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color[800], fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── FOLLOW-UP CARD ─────────────────────────────────────────────────────────

class _FollowUpCard extends StatefulWidget {
  final Map<String, dynamic> appt;
  final TeleMedicineApiClient api;

  const _FollowUpCard({required this.appt, required this.api});

  @override
  State<_FollowUpCard> createState() => _FollowUpCardState();
}

class _FollowUpCardState extends State<_FollowUpCard> {
  bool _uploading = false;

  int _daysRemaining() {
    final raw = widget.appt['slotTime'] ?? widget.appt['createdAt'];
    final dt = raw != null ? DateTime.tryParse(raw.toString()) : null;
    if (dt == null) return 7;
    final elapsed = DateTime.now().difference(dt).inDays;
    return (7 - elapsed).clamp(0, 7);
  }

  Future<void> _uploadReport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      _showSnack('Could not read file. Please try a different file.');
      return;
    }
    setState(() => _uploading = true);
    final apptId = widget.appt['appointmentId']?.toString() ??
        widget.appt['id']?.toString() ?? '';
    final resp = await widget.api.uploadReportBytes(apptId, file.bytes!, file.name);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (resp.success) {
      _showSnack('Report uploaded successfully!');
    } else {
      _showSnack('Upload failed: ${resp.error ?? "unknown error"}');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _daysRemaining();
    final doctorName = widget.appt['doctorName']?.toString() ??
        widget.appt['doctorId']?.toString() ?? 'Doctor';
    final reason = widget.appt['reason']?.toString() ?? 'Consultation';
    final raw = widget.appt['slotTime'] ?? widget.appt['createdAt'];
    final dt = raw != null ? DateTime.tryParse(raw.toString()) : null;
    final dateStr = dt != null
        ? '${dt.day}/${dt.month}/${dt.year}'
        : 'Date unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: remaining <= 1 ? Colors.orange : Colors.teal[200]!,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal[100],
                  child: Icon(Icons.medical_services, color: Colors.teal[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(reason,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: remaining <= 1 ? Colors.orange[50] : Colors.teal[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: remaining <= 1 ? Colors.orange : Colors.teal[200]!,
                    ),
                  ),
                  child: Text(
                    '$remaining day${remaining != 1 ? "s" : ""} left',
                    style: TextStyle(
                      color: remaining <= 1 ? Colors.orange[800] : Colors.teal[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Seen on $dateStr',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 12),
            // Routine check summary chip
            Wrap(
              spacing: 8,
              children: [
                _chip(Icons.science, 'Lab Tests', Colors.purple),
                _chip(Icons.monitor_heart, 'Vitals Check', Colors.red),
                _chip(Icons.medication, 'Prescription', Colors.blue),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file, size: 18),
                    label: Text(_uploading ? 'Uploading…' : 'Upload Test Result'),
                    onPressed: _uploading ? null : _uploadReport,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal[700],
                      side: BorderSide(color: Colors.teal[300]!),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color[700]),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color[700], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── HISTORY CARD (read-only) ───────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> appt;

  const _HistoryCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final doctorName = appt['doctorName']?.toString() ??
        appt['doctorId']?.toString() ?? 'Doctor';
    final reason = appt['reason']?.toString() ?? 'Consultation';
    final status = appt['status']?.toString() ?? 'unknown';
    final raw = appt['slotTime'] ?? appt['createdAt'];
    final dt = raw != null ? DateTime.tryParse(raw.toString()) : null;
    final dateStr = dt != null
        ? '${dt.day}/${dt.month}/${dt.year}'
        : 'Date unknown';

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      case 'scheduled':
      case 'pending':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey[100],
          child: Icon(Icons.medical_services, color: Colors.grey[600]),
        ),
        title: Text(doctorName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$reason • $dateStr'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(20),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
