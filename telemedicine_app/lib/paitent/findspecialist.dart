import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// model & service
import 'doctor_model.dart';
import 'doctor_service.dart';
import 'api_client.dart';

// Ensure this import points to the correct location of your Active Consultation Screen

import 'consultation_waiting_screen.dart';
import 'under_process.dart';
import 'chat_screen.dart';

class FindSpecialistScreen extends StatefulWidget {
  const FindSpecialistScreen({super.key});

  @override
  State<FindSpecialistScreen> createState() => _FindSpecialistScreenState();
}

class _FindSpecialistScreenState extends State<FindSpecialistScreen> {
  int _selectedCategoryIndex = 0;
  final List<String> _categories = [
    'All',
    'General',
    'Cardiologist',
    'Dermatologist',
    'Pediatrician',
  ];

  List<DoctorProfile> _doctors = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors({String? specialization}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service = context.read<DoctorService>();
      final list = await service.fetchAvailableDoctors(specialization: specialization);
      setState(() {
        _doctors = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
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
          'Find a Specialist',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          _buildCategoryFilters(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: Text(
              'Found ${_doctors.length} specialists',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _doctors.isEmpty
                        ? const Center(child: Text('No doctors found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            itemCount: _doctors.length,
                            itemBuilder: (context, index) {
                              return _buildDoctorCard(context, _doctors[index]);
                            },
                          ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search doctor, condition, or specialty...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(_categories[index]),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategoryIndex = index;
                });
                String? spec;
                if (index != 0) {
                  spec = _categories[index];
                }
                _loadDoctors(specialization: spec);
              },
              backgroundColor: Colors.white,
              selectedColor: Colors.teal[700],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.teal[700]! : Colors.grey[300]!,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, DoctorProfile doctor) {
    final specialty = doctor.specialties.isNotEmpty ? doctor.specialties.first : 'General';
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CircleAvatar(
                  radius: 33,
                  backgroundColor: Colors.teal,
                  child: Text(
                    doctor.name.split(' ').first.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            doctor.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              doctor.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specialty,
                      style: TextStyle(
                        color: Colors.teal[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (doctor.bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        doctor.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (doctor.consultationFee != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Fee: â‚¹${doctor.consultationFee!.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (doctor.yearsOfExperience != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${doctor.yearsOfExperience} years experience',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (doctor.qualification != null && doctor.qualification!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        doctor.qualification!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: _buildActionButton(context, doctor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Book appointment then navigate to 60-second waiting screen ---
  void _showConsentAndJoin(BuildContext context, DoctorProfile doctor) {
    final specialty = doctor.specialties.isNotEmpty ? doctor.specialties.first : '';
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Share Health Data',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Do you consent to share your recent symptom logs and health metrics with ${doctor.name} for this session?',
            style: TextStyle(color: Colors.grey[700]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Decline', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _bookAndWait(context, doctor, specialty);
              },
              child: const Text('Consent & Join', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _bookAndWait(
      BuildContext context, DoctorProfile doctor, String specialty) async {
    final service = context.read<DoctorService>();
    final TeleMedicineApiClient api = service.api;
    final reason = 'Teleconsultation with ${doctor.name}';

    // Show booking spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final resp = await api.bookAppointment(
      doctorId: doctor.id,
      slotTime: DateTime.now(),
      reason: reason,
    );

    if (!context.mounted) return;
    Navigator.pop(context); // dismiss spinner

    if (!resp.success || resp.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resp.error ?? 'Could not book appointment. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final appointmentId =
        resp.data!['appointmentId']?.toString() ??
        resp.data!['id']?.toString() ?? '';

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConsultationWaitingScreen(
          appointmentId: appointmentId,
          doctorId: doctor.id,
          doctorName: doctor.name,
          specialty: specialty,
          api: api,
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, DoctorProfile doctor) {
    // Consult + Chat actions
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: ElevatedButton(
            onPressed: () => _showConsentAndJoin(context, doctor),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Consult',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: OutlinedButton(
            onPressed: () async {
              try {
                final service = context.read<DoctorService>();
                final api = service.api;
                final current = api.currentUserId ?? '';
                if (current.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to start chat')));
                  return;
                }
                final resp = await api.startChat([current, doctor.id]);
                if (!mounted) return;
                // ignore_for_file: use_build_context_synchronously
                if (resp.success && resp.data != null && resp.data!['chatId'] != null) {
                  final chatId = resp.data!['chatId'] as String;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(api: api, chatId: chatId),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp.error?.toString() ?? 'Could not start chat')));
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Chat',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: 1, // 'Search' is selected
      onTap: (index) {
        if (index == 0) {
          Navigator.pop(context); // Go back to Dashboard
        } else if (index != 1) {
          String title = 'Feature';
          if (index == 2) title = 'Appointments';
          if (index == 3) title = 'Profile';
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
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Appointments',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
