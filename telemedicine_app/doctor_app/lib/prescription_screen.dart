import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'api_client.dart';

class PrescriptionListScreen extends StatefulWidget {
  final TeleMedicineApiClient api;

  const PrescriptionListScreen({super.key, required this.api});

  @override
  State<PrescriptionListScreen> createState() => _PrescriptionListScreenState();
}

class _PrescriptionListScreenState extends State<PrescriptionListScreen> {
  List<Map<String, dynamic>> _prescriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
  }

  Future<void> _loadPrescriptions() async {
    setState(() => _loading = true);
    final resp = await widget.api.getPrescriptions();
    if (!mounted) return;
    setState(() {
      _prescriptions = resp.success ? (resp.data ?? []) : [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrescriptions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CreatePrescriptionScreen(api: widget.api),
            ),
          );
          if (created == true) _loadPrescriptions();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Prescription'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _prescriptions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('No prescriptions yet'),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap + to create a prescription',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPrescriptions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _prescriptions.length,
                    itemBuilder: (context, index) {
                      final rx = _prescriptions[index];
                      final date = rx['createdAt'] != null
                          ? DateFormat.yMMMd().format(DateTime.tryParse(rx['createdAt'].toString()) ?? DateTime.now())
                          : 'Unknown date';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.medication, color: Colors.blue),
                          ),
                          title: Text(
                            rx['patientName']?.toString() ?? 'Patient #${rx['patientId'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('$date - ${rx['diagnosis'] ?? 'No diagnosis'}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PrescriptionDetailScreen(prescription: rx),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// --- Create Prescription Screen ---
class CreatePrescriptionScreen extends StatefulWidget {
  final TeleMedicineApiClient api;
  final String? patientId;
  final String? patientName;

  const CreatePrescriptionScreen({
    super.key,
    required this.api,
    this.patientId,
    this.patientName,
  });

  @override
  State<CreatePrescriptionScreen> createState() => _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState extends State<CreatePrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientIdController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  final List<Map<String, String>> _medications = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.patientId != null) {
      _patientIdController.text = widget.patientId!;
    }
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addMedication() {
    showDialog(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        final dosageCtrl = TextEditingController();
        final frequencyCtrl = TextEditingController();
        final durationCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Add Medication'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Medication Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dosageCtrl,
                  decoration: const InputDecoration(labelText: 'Dosage (e.g., 500mg)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: frequencyCtrl,
                  decoration: const InputDecoration(labelText: 'Frequency (e.g., 3 times/day)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: durationCtrl,
                  decoration: const InputDecoration(labelText: 'Duration (e.g., 7 days)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _medications.add({
                      'name': nameCtrl.text.trim(),
                      'dosage': dosageCtrl.text.trim(),
                      'frequency': frequencyCtrl.text.trim(),
                      'duration': durationCtrl.text.trim(),
                    });
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _savePrescription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one medication')),
      );
      return;
    }

    setState(() => _saving = true);
    final resp = await widget.api.createPrescription(
      patientId: _patientIdController.text.trim(),
      diagnosis: _diagnosisController.text.trim(),
      medications: _medications,
      notes: _notesController.text.trim(),
    );
    setState(() => _saving = false);

    if (!mounted) return;

    if (resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription created'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.error?.toString() ?? 'Failed to create prescription')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Prescription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _patientIdController,
                decoration: const InputDecoration(
                  labelText: 'Patient ID',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis',
                  prefixIcon: Icon(Icons.medical_information),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Medications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addMedication,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_medications.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('No medications added yet', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ..._medications.asMap().entries.map((entry) {
                  final i = entry.key;
                  final med = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(med['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${med['dosage']} - ${med['frequency']} - ${med['duration']}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _medications.removeAt(i)),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _savePrescription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Prescription',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Prescription Detail Screen ---
class PrescriptionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> prescription;

  const PrescriptionDetailScreen({super.key, required this.prescription});

  Future<void> _sharePdf() async {
    final medications =
        (prescription['medications'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final date = prescription['createdAt'] != null
        ? DateFormat.yMMMd().format(
            DateTime.tryParse(prescription['createdAt'].toString()) ??
                DateTime.now())
        : 'Unknown date';
    final id = prescription['prescriptionId']?.toString() ?? 'rx';

    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text('MEDICAL PRESCRIPTION',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 8),
          pw.Text(
              'Patient: ${prescription['patientName'] ?? prescription['patientId'] ?? 'Unknown'}',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 8),
          if ((prescription['diagnosis']?.toString() ?? '').isNotEmpty) ...[
            pw.Text('Diagnosis',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800)),
            pw.Text(prescription['diagnosis'].toString(),
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 8),
          ],
          if ((prescription['notes']?.toString() ?? '').isNotEmpty) ...[
            pw.Text('Notes',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800)),
            pw.Text(prescription['notes'].toString(),
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 8),
          ],
          pw.Text('Medications',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800)),
          pw.SizedBox(height: 4),
          if (medications.isEmpty)
            pw.Text('No medications listed.',
                style: const pw.TextStyle(fontSize: 10))
          else
            pw.TableHelper.fromTextArray(
              headerStyle:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              headers: ['#', 'Medicine', 'Dosage', 'Frequency', 'Duration'],
              data: List.generate(medications.length, (i) {
                final m = medications[i];
                return [
                  '${i + 1}',
                  m['name']?.toString() ?? 'Medicine',
                  m['dosage']?.toString() ?? '-',
                  m['frequency']?.toString() ?? '-',
                  m['duration']?.toString() ?? '-',
                ];
              }),
            ),
        ],
      ),
    ));

    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'prescription_$id.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final medications = (prescription['medications'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final date = prescription['createdAt'] != null
        ? DateFormat.yMMMd().format(DateTime.tryParse(prescription['createdAt'].toString()) ?? DateTime.now())
        : 'Unknown date';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Share PDF',
            onPressed: _sharePdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Patient: ${prescription['patientName'] ?? prescription['patientId'] ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey, size: 16),
                        const SizedBox(width: 8),
                        Text(date, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text('Diagnosis', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      prescription['diagnosis']?.toString() ?? 'Not specified',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (prescription['notes'] != null && prescription['notes'].toString().isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(prescription['notes'].toString()),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Medications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (medications.isEmpty)
              const Text('No medications listed')
            else
              ...medications.asMap().entries.map((entry) {
                final i = entry.key;
                final med = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue,
                          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med['name']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${med['dosage'] ?? ''} | ${med['frequency'] ?? ''} | ${med['duration'] ?? ''}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
