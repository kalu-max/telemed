import 'package:flutter/material.dart';
import 'api_client.dart';
import 'chat_screen.dart';
import 'prescription_screen.dart';

class PatientListScreen extends StatefulWidget {
  final TeleMedicineApiClient api;
  final void Function(String patientId, String patientName)? onCallPatient;

  const PatientListScreen({
    super.key,
    required this.api,
    this.onCallPatient,
  });

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  List<Map<String, dynamic>> _patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _loading = true);
    // Get patients from appointments (unique patients)
    final resp = await widget.api.getAppointments();
    if (!mounted) return;

    if (resp.success && resp.data != null) {
      final seen = <String>{};
      final patients = <Map<String, dynamic>>[];
      for (final appt in resp.data!) {
        final patientId = appt['patientId']?.toString() ?? '';
        if (patientId.isNotEmpty && seen.add(patientId)) {
          patients.add({
            'patientId': patientId,
            'patientName': appt['patientName']?.toString() ?? 'Patient #$patientId',
            'reason': appt['reason']?.toString() ?? '',
            'lastSeen': appt['slotTime']?.toString() ?? '',
          });
        }
      }
      setState(() {
        _patients = patients;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_patients.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No patients yet'),
            const SizedBox(height: 8),
            Text(
              'Patients will appear here after appointments',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPatients,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _patients.length,
        itemBuilder: (context, index) {
          final patient = _patients[index];
          final patientId = patient['patientId'] ?? '';
          final patientName = patient['patientName'] ?? 'Unknown';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Text(
                          patientName.toString().isNotEmpty ? patientName[0].toUpperCase() : 'P',
                          style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patientName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'ID: $patientId',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (patient['reason']?.toString().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Reason: ${patient['reason']}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.videocam, size: 18),
                          label: const Text('Call'),
                          onPressed: () {
                            widget.onCallPatient?.call(patientId, patientName);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('Chat'),
                          onPressed: () async {
                            final resp = await widget.api.startChat(
                              [widget.api.currentUserId ?? '', patientId],
                            );
                            if (resp.success && resp.data?['chatId'] != null && context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    api: widget.api,
                                    chatId: resp.data!['chatId'],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.medication, size: 18),
                          label: const Text('Rx'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreatePrescriptionScreen(
                                  api: widget.api,
                                  patientId: patientId,
                                  patientName: patientName,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
