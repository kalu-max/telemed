import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/prescription_model.dart';

/// Prescription pad for doctors to create prescriptions during consultation
class PrescriptionPadWidget extends StatefulWidget {
  final String consultationId;
  final String patientName;
  final String patientId;
  final Function(Prescription) onSavePrescription;

  const PrescriptionPadWidget({
    super.key,
    required this.consultationId,
    required this.patientName,
    required this.patientId,
    required this.onSavePrescription,
  });

  @override
  State<PrescriptionPadWidget> createState() => _PrescriptionPadWidgetState();
}

class _PrescriptionPadWidgetState extends State<PrescriptionPadWidget> {
  final _symptomsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _clinicalNotesController = TextEditingController();
  final _dietaryController = TextEditingController();
  final _lifestyleController = TextEditingController();
  final _followUpController = TextEditingController();

  final List<Medicine> _selectedMedicines = [];
  final List<String> _labTests = [];
  DateTime? _followUpDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Prescription'),
        backgroundColor: Colors.teal[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal[200]!),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.teal[600],
                    child: Text(
                      widget.patientName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Patient',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          widget.patientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Symptoms
            _buildSection(
              'Symptoms',
              _buildTextField(
                _symptomsController,
                'Enter patient symptoms',
                maxLines: 3,
              ),
            ),

            // Diagnosis
            _buildSection(
              'Diagnosis',
              _buildTextField(
                _diagnosisController,
                'Enter diagnosis',
                maxLines: 3,
              ),
            ),

            // Clinical Notes
            _buildSection(
              'Clinical Notes',
              _buildTextField(
                _clinicalNotesController,
                'Add clinical notes (optional)',
                maxLines: 2,
              ),
            ),

            // Medicines Section
            _buildSection(
              'Medicines',
              Column(
                children: [
                  ..._selectedMedicines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final medicine = entry.value;
                    return _MedicineCard(
                      medicine: medicine,
                      onEdit: () => _editMedicine(index),
                      onDelete: () => _deleteMedicine(index),
                    );
                  }),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _addMedicine,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Medicine'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Lab Tests
            _buildSection(
              'Recommended Lab Tests (Optional)',
              Column(
                children: [
                  ..._labTests.asMap().entries.map((entry) {
                    return _LabTestChip(
                      test: entry.value,
                      onRemove: () => _removeLabTest(entry.key),
                    );
                  }),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _addLabTest,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Lab Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            // Dietary Instructions
            _buildSection(
              'Dietary Instructions (Optional)',
              _buildTextField(
                _dietaryController,
                'Enter dietary instructions',
                maxLines: 2,
              ),
            ),

            // Lifestyle Instructions
            _buildSection(
              'Lifestyle Instructions (Optional)',
              _buildTextField(
                _lifestyleController,
                'Enter lifestyle instructions',
                maxLines: 2,
              ),
            ),

            // Follow-up
            _buildSection(
              'Follow-up',
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectFollowUpDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _followUpDate == null
                                  ? 'Select follow-up date'
                                  : DateFormat('dd/MM/yyyy').format(_followUpDate!),
                              style: TextStyle(
                                color: _followUpDate == null ? Colors.grey[600] : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    _followUpController,
                    'Follow-up instructions',
                    maxLines: 2,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _savePrescription,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const SizedBox(
                width: double.infinity,
                child: Text(
                  'Issue Prescription',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  void _addMedicine() {
    showDialog(
      context: context,
      builder: (context) => _AddMedicineDialog(
        onAdd: (medicine) {
          setState(() => _selectedMedicines.add(medicine));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _editMedicine(int index) {
    showDialog(
      context: context,
      builder: (context) => _AddMedicineDialog(
        initialMedicine: _selectedMedicines[index],
        onAdd: (medicine) {
          setState(() => _selectedMedicines[index] = medicine);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _deleteMedicine(int index) {
    setState(() => _selectedMedicines.removeAt(index));
  }

  void _addLabTest() {
    showDialog(
      context: context,
      builder: (context) => _AddLabTestDialog(
        onAdd: (test) {
          setState(() => _labTests.add(test));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _removeLabTest(int index) {
    setState(() => _labTests.removeAt(index));
  }

  void _selectFollowUpDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _followUpDate = date);
    }
  }

  void _savePrescription() {
    if (_selectedMedicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one medicine')),
      );
      return;
    }

    final prescription = Prescription(
      prescriptionId: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: widget.patientId,
      patientName: widget.patientName,
      patientEmail: '', // Should be fetched
      patientPhone: '', // Should be fetched
      doctorId: '', // Should be fetched from auth
      doctorName: '', // Should be fetched from auth
      consultationId: widget.consultationId,
      consultationDate: DateTime.now(),
      symptoms: _symptomsController.text,
      diagnosis: _diagnosisController.text,
      clinicalNotes: _clinicalNotesController.text,
      medicines: _selectedMedicines,
      dietaryInstructions: _dietaryController.text.isEmpty ? null : _dietaryController.text,
      lifestyleInstructions: _lifestyleController.text.isEmpty ? null : _lifestyleController.text,
      followUpInstructions: _followUpController.text.isEmpty ? null : _followUpController.text,
      followUpDate: _followUpDate,
      status: PrescriptionStatus.active,
      issuedAt: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 30)),
      isEncrypted: true,
      labTests: _labTests.isEmpty ? null : _labTests,
      patientViewed: false,
      createdAt: DateTime.now(),
    );

    widget.onSavePrescription(prescription);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    _diagnosisController.dispose();
    _clinicalNotesController.dispose();
    _dietaryController.dispose();
    _lifestyleController.dispose();
    _followUpController.dispose();
    super.dispose();
  }
}

/// View for displaying saved prescription
class PrescriptionViewWidget extends StatelessWidget {
  final Prescription prescription;
  final VoidCallback? onDownloadPdf;
  final VoidCallback? onShare;

  const PrescriptionViewWidget({
    super.key,
    required this.prescription,
    this.onDownloadPdf,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription'),
        backgroundColor: Colors.teal[700],
        actions: [
          if (onDownloadPdf != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: onDownloadPdf,
            ),
          if (onShare != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: onShare,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(prescription.status).withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getStatusColor(prescription.status)),
              ),
              child: Text(
                prescription.status.toString().split('.').last.toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(prescription.status),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Doctor & Patient Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _InfoRow('Doctor', prescription.doctorName),
                  _InfoRow('Patient', prescription.patientName),
                  _InfoRow('Date', DateFormat('dd/MM/yyyy').format(prescription.issuedAt)),
                  if (prescription.expiryDate != null)
                    _InfoRow('Valid Until', DateFormat('dd/MM/yyyy').format(prescription.expiryDate!)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Medicines Section
            _SectionHeader('Medicines'),
            ..._buildMedicineCards(),
            const SizedBox(height: 24),

            // Additional Info
            if (prescription.diagnosis != null)
              _buildInfoSection('Diagnosis', prescription.diagnosis),
            if (prescription.symptoms != null)
              _buildInfoSection('Symptoms', prescription.symptoms),
            if (prescription.dietaryInstructions != null)
              _buildInfoSection('Dietary Instructions', prescription.dietaryInstructions),
            if (prescription.lifestyleInstructions != null)
              _buildInfoSection('Lifestyle Instructions', prescription.lifestyleInstructions),
            if (prescription.followUpInstructions != null)
              _buildInfoSection('Follow-up Instructions', prescription.followUpInstructions),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMedicineCards() {
    return prescription.medicines.map((med) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              med.medicineName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text('${med.dosage} ${med.dosageUnit}'),
            Text('${med.frequency} for ${med.durationDays} days'),
            if (med.instructions != null) Text('Note: ${med.instructions}'),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildInfoSection(String title, String? content) {
    if (content == null || content.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(content),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Color _getStatusColor(PrescriptionStatus status) {
    switch (status) {
      case PrescriptionStatus.active:
        return Colors.green;
      case PrescriptionStatus.expired:
        return Colors.red;
      case PrescriptionStatus.completed:
        return Colors.blue;
      case PrescriptionStatus.cancelled:
        return Colors.grey;
      case PrescriptionStatus.draft:
        return Colors.orange;
    }
  }
}

/// Simplified view for medicine reminders
class MedicineReminderWidget extends StatelessWidget {
  final String medicineName;
  final String dosage;
  final String frequency;
  final DateTime nextReminder;
  final double adherencePercentage;
  final VoidCallback onMarkTaken;

  const MedicineReminderWidget({
    super.key,
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.nextReminder,
    required this.adherencePercentage,
    required this.onMarkTaken,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicineName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '$dosage • $frequency',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getAdherenceColor(adherencePercentage).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${adherencePercentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: _getAdherenceColor(adherencePercentage),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next: ${DateFormat('hh:mm a').format(nextReminder)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              ElevatedButton(
                onPressed: onMarkTaken,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: const Text('Mark Taken', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getAdherenceColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }
}

// Helper Widgets

class _MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicineCard({
    required this.medicine,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medicine.medicineName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${medicine.dosage} ${medicine.dosageUnit} • ${medicine.frequency}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
          IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: onDelete),
        ],
      ),
    );
  }
}

class _LabTestChip extends StatelessWidget {
  final String test;
  final VoidCallback onRemove;

  const _LabTestChip({required this.test, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(test),
      onDeleted: onRemove,
      backgroundColor: Colors.blue[50],
    );
  }
}

class _AddMedicineDialog extends StatefulWidget {
  final Medicine? initialMedicine;
  final Function(Medicine) onAdd;

  const _AddMedicineDialog({this.initialMedicine, required this.onAdd});

  @override
  State<_AddMedicineDialog> createState() => _AddMedicineDialogState();
}

class _AddMedicineDialogState extends State<_AddMedicineDialog> {
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _frequencyController;
  late TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialMedicine?.medicineName);
    _dosageController = TextEditingController(text: widget.initialMedicine?.dosage.toString());
    _frequencyController = TextEditingController(text: widget.initialMedicine?.frequency);
    _durationController = TextEditingController(text: widget.initialMedicine?.durationDays.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Medicine'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Medicine Name'),
            ),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(labelText: 'Dosage (e.g., 500 mg)'),
            ),
            TextField(
              controller: _frequencyController,
              decoration: const InputDecoration(labelText: 'Frequency (e.g., Twice Daily)'),
            ),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration (days)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final medicine = Medicine(
              medicineId: DateTime.now().millisecondsSinceEpoch.toString(),
              medicineName: _nameController.text,
              dosage: double.tryParse(_dosageController.text) ?? 0,
              dosageUnit: 'mg',
              frequency: _frequencyController.text,
              durationDays: int.tryParse(_durationController.text) ?? 7,
            );
            widget.onAdd(medicine);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}

class _AddLabTestDialog extends StatefulWidget {
  final Function(String) onAdd;

  const _AddLabTestDialog({required this.onAdd});

  @override
  State<_AddLabTestDialog> createState() => _AddLabTestDialogState();
}

class _AddLabTestDialogState extends State<_AddLabTestDialog> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Lab Test'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'e.g., Complete Blood Count'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              widget.onAdd(controller.text);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }
}
