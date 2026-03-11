import 'package:flutter/material.dart';
import 'api_client.dart';

/// Displays read-only consultation notes for a completed consultation.
class ConsultationNotesScreen extends StatefulWidget {
  final TeleMedicineApiClient api;
  final String consultationId;

  const ConsultationNotesScreen({
    super.key,
    required this.api,
    required this.consultationId,
  });

  @override
  State<ConsultationNotesScreen> createState() => _ConsultationNotesScreenState();
}

class _ConsultationNotesScreenState extends State<ConsultationNotesScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() { _loading = true; _error = null; });
    final resp = await widget.api.getConsultationNotes(widget.consultationId);
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      setState(() { _data = resp.data!; _loading = false; });
    } else {
      setState(() { _error = resp.error?.toString() ?? 'Failed to load notes'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation Notes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _loadNotes, child: const Text('Retry')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadNotes,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _header(),
                      const SizedBox(height: 16),
                      _section('Doctor Notes', _data['notes']?.toString()),
                      const SizedBox(height: 12),
                      _section('Prescription', _data['prescription']?.toString()),
                      const SizedBox(height: 12),
                      _section('Status', _data['status']?.toString()),
                      if (_data['completedAt'] != null) ...[
                        const SizedBox(height: 12),
                        _section('Completed', _data['completedAt'].toString()),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _header() {
    final doctorName = _data['doctorName']?.toString() ?? 'Doctor';
    return Card(
      color: Colors.teal.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.medical_information, color: Colors.teal, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dr. $doctorName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Consultation #${widget.consultationId}', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String? content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
            const SizedBox(height: 8),
            Text(content?.isNotEmpty == true ? content! : 'Not available',
                style: TextStyle(color: content?.isNotEmpty == true ? Colors.black87 : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
