import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'api_client.dart';

/// Shows all prescriptions for the logged-in patient, loaded from the backend.
/// Accessible via the `/prescription` named route or pushed directly.
class PrescriptionDetailsScreen extends StatefulWidget {
  const PrescriptionDetailsScreen({super.key});

  @override
  State<PrescriptionDetailsScreen> createState() =>
      _PrescriptionDetailsScreenState();
}

class _PrescriptionDetailsScreenState
    extends State<PrescriptionDetailsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _prescriptions = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<TeleMedicineApiClient>();
      final resp = await api.getPrescriptions();
      if (!mounted) return;
      if (resp.success && resp.data != null) {
        setState(() {
          _prescriptions = resp.data!;
          _loading = false;
        });
      } else {
        setState(() {
          _error = resp.error ?? 'Could not load prescriptions';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Prescriptions',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _prescriptions.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No Prescriptions Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Prescriptions written by your doctors will appear here.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prescriptions.length,
      itemBuilder: (context, i) =>
          _PrescriptionCard(prescription: _prescriptions[i]),
    );
  }
}

// ── Single prescription card ──────────────────────────────────────────────

class _PrescriptionCard extends StatefulWidget {
  final Map<String, dynamic> prescription;
  const _PrescriptionCard({required this.prescription});

  @override
  State<_PrescriptionCard> createState() => _PrescriptionCardState();
}

class _PrescriptionCardState extends State<_PrescriptionCard> {
  bool _expanded = false;

  String _formatDate(dynamic raw) {
    if (raw == null) return 'Unknown date';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  List<dynamic> _medications() {
    final meds = widget.prescription['medications'];
    if (meds is List) return meds;
    return [];
  }

  void _copyToClipboard() {
    final p = widget.prescription;
    final meds = _medications()
        .map((m) =>
            '  - ${m['name'] ?? m['medName'] ?? 'Medicine'} '
            '${m['dosage'] ?? ''} '
            '${m['frequency'] ?? ''} for ${m['duration'] ?? ''}'.trim())
        .join('\n');
    final text = '''
Prescription
Doctor: ${p['doctorName'] ?? p['doctorId'] ?? 'Unknown'}
Date: ${_formatDate(p['createdAt'] ?? p['date'])}
Diagnosis: ${p['diagnosis'] ?? 'N/A'}
Medications:
$meds
Instructions: ${p['instructions'] ?? 'None'}
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prescription copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prescription;
    final doctorName =
        p['doctorName']?.toString() ?? p['doctorId']?.toString() ?? 'Doctor';
    final diagnosis = p['diagnosis']?.toString() ?? 'Consultation';
    final date = _formatDate(p['createdAt'] ?? p['date']);
    final meds = _medications();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.medical_services, color: Colors.teal[700]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doctorName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(diagnosis,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(date,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.medication_outlined,
                              size: 13, color: Colors.teal[600]),
                          const SizedBox(width: 3),
                          Text('${meds.length} med${meds.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                  color: Colors.teal[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),

          // Expanded medicines + actions
          if (_expanded) ...[
            const Divider(height: 1),
            if (meds.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No medications listed.',
                    style: TextStyle(color: Colors.grey[500])),
              )
            else
              ...meds.map((m) => _MedRow(med: m as Map<String, dynamic>)),
            if (p['instructions'] != null &&
                p['instructions'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p['instructions'].toString(),
                          style: TextStyle(
                              color: Colors.orange[900], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Prescription'),
                  onPressed: _copyToClipboard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal[700],
                    side: BorderSide(color: Colors.teal[300]!),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MedRow extends StatelessWidget {
  final Map<String, dynamic> med;
  const _MedRow({required this.med});

  @override
  Widget build(BuildContext context) {
    final name = med['name']?.toString() ??
        med['medName']?.toString() ??
        med['medication']?.toString() ??
        'Medicine';
    final dosage = med['dosage']?.toString() ?? '';
    final frequency = med['frequency']?.toString() ?? '';
    final duration = med['duration']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: Colors.teal[400]!, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.medication, color: Colors.teal[700], size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                if (dosage.isNotEmpty)
                  Text(dosage,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12)),
                if (frequency.isNotEmpty || duration.isNotEmpty)
                  const SizedBox(height: 6),
                if (frequency.isNotEmpty || duration.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: [
                      if (frequency.isNotEmpty)
                        _chip(Icons.schedule, frequency),
                      if (duration.isNotEmpty)
                        _chip(Icons.calendar_today, duration),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.teal[700]),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800])),
        ],
      ),
    );
  }
}
