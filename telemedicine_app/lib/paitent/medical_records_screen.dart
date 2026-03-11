import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_client.dart';

/// Screen for patients to view their medical records.
class MedicalRecordsScreen extends StatefulWidget {
  final TeleMedicineApiClient api;

  const MedicalRecordsScreen({super.key, required this.api});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _records = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() { _loading = true; _error = null; });
    final resp = await widget.api.getMedicalRecords();
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      final list = resp.data!['records'];
      setState(() {
        _records = List<Map<String, dynamic>>.from(list ?? []);
        _loading = false;
      });
    } else {
      setState(() { _error = resp.error?.toString() ?? 'Failed to load'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medical Records')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: _loadRecords, child: const Text('Retry')),
                  ],
                ))
              : _records.isEmpty
                  ? const Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No medical records yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ))
                  : RefreshIndicator(
                      onRefresh: _loadRecords,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _records.length,
                        itemBuilder: (ctx, i) => _buildRecordCard(_records[i]),
                      ),
                    ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final createdAt = record['createdAt'] != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(record['createdAt'].toString()))
        : 'Unknown date';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_information, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record['diagnosis']?.toString() ?? 'No diagnosis',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (record['treatment'] != null && record['treatment'].toString().isNotEmpty) ...[
              Text('Treatment: ${record['treatment']}', style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 4),
            ],
            Text(createdAt, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
