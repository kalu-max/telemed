import 'package:flutter/material.dart';
import 'api_client.dart';

class CalendarScreen extends StatefulWidget {
  final TeleMedicineApiClient api;
  const CalendarScreen({super.key, required this.api});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final resp = await widget.api.getAppointments();
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      setState(() {
        _appointments = resp.data!;
        _loading = false;
      });
    } else {
      setState(() {
        _error = resp.error?.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Appointments')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _appointments.isEmpty
                  ? const Center(child: Text('No appointments'))
                  : ListView.separated(
                      itemCount: _appointments.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final appt = _appointments[index];
                        final slot = appt['slotTime'];
                        final date = slot != null ? DateTime.tryParse(slot.toString()) : null;
                        return ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text(appt['doctorName'] ?? appt['patientName'] ?? ''),
                          subtitle: Text(date != null
                              ? '${date.toLocal()}'.split('.').first
                              : appt['reason'] ?? ''),
                          trailing: Text(appt['status'] ?? ''),
                        );
                      },
                    ),
    );
  }
}
