import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presence/models/presence_model.dart';
import '../../presence/providers/presence_provider.dart';
import '../../presence/widgets/doctor_availability_widgets.dart';
import '../../prescription/models/prescription_model.dart';
import '../../prescription/providers/prescription_provider.dart';
import '../../prescription/widgets/prescription_widgets.dart';
import '../../communication/providers/communication_providers.dart';
import '../../communication/widgets/call_widgets.dart';

///
/// Unified consultation flow combining doctor selection, real-time communication, and prescriptions
/// This is the main entry point for patients to start a consultation
///
class UnifiedConsultationFlow extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String patientEmail;
  final String patientPhone;

  const UnifiedConsultationFlow({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.patientPhone,
  });

  @override
  State<UnifiedConsultationFlow> createState() => _UnifiedConsultationFlowState();
}

class _UnifiedConsultationFlowState extends State<UnifiedConsultationFlow> {
  int _currentStep = 0; // 0: Select Doctor, 1: Consultation, 2: Prescription
  DoctorPresence? _selectedDoctor;
  ConsultationType _selectedConsultationType = ConsultationType.videoCall;
  String? _consultationId;

  final List<String> _steps = ['Select Doctor', 'Consultation', 'Prescription'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableDoctors();
    });
  }

  void _loadAvailableDoctors() {
    final presenceProvider = context.read<PresenceProvider>();
    presenceProvider.getAvailableDoctors(limit: 50);
  }

  void _selectDoctor(DoctorPresence doctor) {
    setState(() {
      _selectedDoctor = doctor;
      _currentStep = 1;
    });

    // Watch this doctor's presence
    context.read<PresenceProvider>().watchDoctor(doctor.doctorId);

    // Show consultation type selector
    _showConsultationTypeSelector();
  }

  void _showConsultationTypeSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Consultation Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (_selectedDoctor!.consultationType == ConsultationType.videoCall ||
                _selectedDoctor!.consultationType == ConsultationType.all)
              _ConsultationTypeOption(
                icon: Icons.videocam,
                title: 'Video Call',
                description: 'Face-to-face video consultation',
                fee: _selectedDoctor!.consultationFee ?? 500,
                onSelect: () {
                  setState(() => _selectedConsultationType = ConsultationType.videoCall);
                  Navigator.pop(context);
                  _startConsultation();
                },
              ),
            const SizedBox(height: 12),
            if (_selectedDoctor!.consultationType == ConsultationType.audioCall ||
                _selectedDoctor!.consultationType == ConsultationType.all)
              _ConsultationTypeOption(
                icon: Icons.call,
                title: 'Audio Call',
                description: 'Voice-only consultation',
                fee: (_selectedDoctor!.consultationFee ?? 500) - 100,
                onSelect: () {
                  setState(() => _selectedConsultationType = ConsultationType.audioCall);
                  Navigator.pop(context);
                  _startConsultation();
                },
              ),
            const SizedBox(height: 12),
            if (_selectedDoctor!.consultationType == ConsultationType.chat ||
                _selectedDoctor!.consultationType == ConsultationType.all)
              _ConsultationTypeOption(
                icon: Icons.chat,
                title: 'Text Chat',
                description: 'Asynchronous text chat',
                fee: (_selectedDoctor!.consultationFee ?? 500) - 200,
                onSelect: () {
                  setState(() => _selectedConsultationType = ConsultationType.chat);
                  Navigator.pop(context);
                  _startConsultation();
                },
              ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _startConsultation() {
    // Generate consultation ID
    _consultationId = DateTime.now().millisecondsSinceEpoch.toString();

    // Start communication based on selected type
    switch (_selectedConsultationType) {
      case ConsultationType.videoCall:
        // Launch real WebRTC video call
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              recipientId: _selectedDoctor!.doctorId,
              recipientName: _selectedDoctor!.doctorName,
              conversationId: _consultationId!,
            ),
          ),
        );
        break;
      case ConsultationType.audioCall:
        // Initiate audio call via video provider in audio-only mode
        context.read<VideoCallingProvider>().initiateVideoCall(
          receiverId: _selectedDoctor!.doctorId,
          receiverName: _selectedDoctor!.doctorName,
        ).then((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio call started')),
          );
        }).catchError((e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start call: $e')),
          );
        });
        break;
      case ConsultationType.chat:
        // Open chat screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening chat...')),
        );
        break;
      case ConsultationType.all:
        break;
    }

    // Update doctor presence
    context.read<PresenceProvider>().watchDoctor(_selectedDoctor!.doctorId);
  }

  void _onConsultationEnd() {
    // Move to prescription step
    setState(() => _currentStep = 2);
  }

  void _onPrescriptionSave(Prescription prescription) {
    // Save prescription via PrescriptionProvider
    context.read<PrescriptionProvider>().createPrescription(
      patientId: widget.patientId,
      patientName: widget.patientName,
      patientEmail: widget.patientEmail,
      patientPhone: widget.patientPhone,
      doctorId: _selectedDoctor!.doctorId,
      doctorName: _selectedDoctor!.doctorName,
      consultationId: _consultationId!,
      consultationDate: DateTime.now(),
      symptoms: prescription.symptoms,
      diagnosis: prescription.diagnosis,
      clinicalNotes: prescription.clinicalNotes,
      medicines: prescription.medicines,
      dietaryInstructions: prescription.dietaryInstructions,
      lifestyleInstructions: prescription.lifestyleInstructions,
      followUpInstructions: prescription.followUpInstructions,
      followUpDate: prescription.followUpDate,
      labTests: prescription.labTests,
    ).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription saved successfully!')),
      );
      if (!mounted) return;
      Navigator.pop(context); // Go back to dashboard
    }).catchError((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Consultation - ${_steps[_currentStep]}'),
        backgroundColor: Colors.teal[700],
        elevation: 0,
      ),
      body: _buildConsultationStep(),
    );
  }

  Widget _buildConsultationStep() {
    switch (_currentStep) {
      case 0:
        return _buildDoctorSelectionStep();
      case 1:
        return _buildConsultationContentStep();
      case 2:
        return _buildPrescriptionStep();
      default:
        return const Center(child: Text('Unknown step'));
    }
  }

  Widget _buildDoctorSelectionStep() {
    return Consumer<PresenceProvider>(
      builder: (context, presenceProvider, child) {
        final doctors = presenceProvider.availableDoctors;

        if (doctors.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No doctors available',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _loadAvailableDoctors,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600],
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              _buildStepIndicator(),
              const SizedBox(height: 24),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  'Select an available doctor to start your consultation. Doctors are sorted by availability, ratings, and response time.',
                  style: TextStyle(color: Colors.blue[900], fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),

              // Doctor list
              AvailableDoctorsList(
                doctors: doctors,
                onDoctorSelected: _selectDoctor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConsultationContentStep() {
    if (_selectedDoctor == null) {
      return const Center(child: Text('No doctor selected'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepIndicator(),
          const SizedBox(height: 24),

          // Doctor header
          DoctorSelectionHeader(
            doctor: _selectedDoctor!,
            selectedType: _selectedConsultationType,
            onTypeChanged: (type) {
              setState(() => _selectedConsultationType = type);
              // Update communication provider
              _startConsultation();
            },
          ),
          const SizedBox(height: 24),

          // Consultation view (will depend on selected type)
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedConsultationType == ConsultationType.videoCall
                        ? Icons.videocam
                        : _selectedConsultationType == ConsultationType.audioCall
                            ? Icons.call
                            : Icons.chat,
                    size: 48,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedConsultationType == ConsultationType.videoCall
                        ? 'Video Call Active'
                        : _selectedConsultationType == ConsultationType.audioCall
                            ? 'Audio Call Active'
                            : 'Chat Active',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '(Communication UI would go here)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // End consultation button
          ElevatedButton(
            onPressed: _onConsultationEnd,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('End Consultation'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionStep() {
    return PrescriptionPadWidget(
      consultationId: _consultationId!,
      patientName: widget.patientName,
      patientId: widget.patientId,
      onSavePrescription: _onPrescriptionSave,
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(_steps.length, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;

        return Expanded(
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.teal[600]
                      : isCompleted
                          ? Colors.green
                          : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _steps[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.teal[600] : Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    if (_selectedDoctor != null) {
      context.read<PresenceProvider>().unwatchDoctor(_selectedDoctor!.doctorId);
    }
    super.dispose();
  }
}

/// Consultation type option widget
class _ConsultationTypeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final int fee;
  final VoidCallback onSelect;

  const _ConsultationTypeOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.fee,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.teal[600], size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              Text('₹$fee', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
