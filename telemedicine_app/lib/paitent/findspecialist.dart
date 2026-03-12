import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// model & service
import 'doctor_model.dart';
import 'doctor_service.dart';
import 'api_client.dart';

// Ensure this import points to the correct location of your Active Consultation Screen
import 'consultation_waiting_screen.dart';
import 'chat_screen.dart';
import 'doctor_reviews_screen.dart';
import 'calendar.dart';

class FindSpecialistScreen extends StatefulWidget {
  const FindSpecialistScreen({super.key});

  @override
  State<FindSpecialistScreen> createState() => _FindSpecialistScreenState();
}

class _FindSpecialistScreenState extends State<FindSpecialistScreen> {
  int _selectedCategoryIndex = 0;
  final List<String> _categories = [
    'All',
    'General Practitioner',
    'Cardiologist',
    'Dermatologist',
    'Pediatrician',
    'Orthopedist',
    'Neurologist',
    'Psychiatrist',
    'Urologist',
    'Ophthalmologist',
    'Otolaryngologist',
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
      if (!mounted) return;
      setState(() {
        _doctors = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
        onChanged: (query) {
          if (query.length >= 2) {
            _searchDoctors(query);
          } else if (query.isEmpty) {
            _loadDoctors(specialization: _selectedCategoryIndex == 0 ? null : _categories[_selectedCategoryIndex]);
          }
        },
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

  void _searchDoctors(String query) async {
    try {
      final service = context.read<DoctorService>();
      final resp = await service.api.search(query);
      if (!mounted) return;
      if (resp.success && resp.data != null) {
        final doctorResults = (resp.data!['doctors'] as List?) ?? [];
        final searchedDoctors = doctorResults.map((d) {
          final map = Map<String, dynamic>.from(d);
          return DoctorProfile(
            id: map['userId'] ?? '',
            name: map['name'] ?? 'Doctor',
            specialties: [map['specialization'] ?? 'General'],
            rating: (map['rating'] ?? 0).toDouble(),
            bio: map['bio'] ?? '',
            yearsOfExperience: map['yearsOfExperience'],
            consultationFee: map['consultationFee'] != null ? (map['consultationFee'] as num).toDouble() : null,
          );
        }).toList();
        setState(() { _doctors = searchedDoctors; });
      }
    } catch (_) {}
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
                        'Fee: ₹${doctor.consultationFee!.toStringAsFixed(0)}',
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
              // Reviews link
              TextButton.icon(
                onPressed: () {
                  final service = context.read<DoctorService>();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorReviewsScreen(
                        api: service.api,
                        doctorId: doctor.id,
                        doctorName: doctor.name,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.star, size: 16, color: Colors.amber),
                label: const Text('Reviews', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
              const Spacer(),
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
                _showSlotPicker(context, doctor, specialty);
              },
              child: const Text('Consent & Continue', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSlotPicker(BuildContext context, DoctorProfile doctor, String specialty) async {
    final service = context.read<DoctorService>();
    final TeleMedicineApiClient api = service.api;
    DateTime selectedDate = DateTime.now();
    List<Map<String, dynamic>> availableSlots = [];
    String? selectedTime;
    bool loadingSlots = false;
    bool slotsLoaded = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> loadSlots() async {
              setSheetState(() { loadingSlots = true; selectedTime = null; });
              final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
              final resp = await api.getDoctorTimeSlots(doctor.id, dateStr);
              if (!ctx.mounted) return;
              if (resp.success && resp.data != null) {
                final slots = (resp.data!['slots'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                setSheetState(() { availableSlots = slots; loadingSlots = false; slotsLoaded = true; });
              } else {
                setSheetState(() { availableSlots = []; loadingSlots = false; slotsLoaded = true; });
              }
            }

            // Load once on first build only
            if (!slotsLoaded && !loadingSlots) {
              Future.microtask(loadSlots);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16, right: 16, top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Book with ${doctor.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  // Date picker
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) {
                            selectedDate = picked;
                            await loadSlots();
                          }
                        },
                        child: const Text('Change Date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Available Time Slots', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (loadingSlots)
                    const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                  else if (availableSlots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.event_busy, color: Colors.grey[400], size: 40),
                            const SizedBox(height: 8),
                            Text('No slots available on this day', style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text('Try picking another date or book now', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableSlots.map((slot) {
                        final time = slot['time'] as String;
                        final available = slot['available'] == true;
                        final isSelected = selectedTime == time;
                        return ChoiceChip(
                          label: Text(time),
                          selected: isSelected,
                          onSelected: available ? (selected) {
                            setSheetState(() { selectedTime = selected ? time : null; });
                          } : null,
                          backgroundColor: available ? Colors.white : Colors.grey[200],
                          selectedColor: Colors.teal[700],
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (available ? Colors.black87 : Colors.grey),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: isSelected ? Colors.teal[700]! : Colors.grey[300]!),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (selectedTime != null) {
                          // Parse the selected time into a DateTime
                          final parts = selectedTime!.split(':');
                          final slotDateTime = DateTime(
                            selectedDate.year, selectedDate.month, selectedDate.day,
                            int.parse(parts[0]), int.parse(parts[1]),
                          );
                          _bookAndWait(context, doctor, specialty, slotDateTime);
                        } else {
                          // Book immediately (now) if no slots available
                          _bookAndWait(context, doctor, specialty, DateTime.now());
                        }
                      },
                      child: Text(
                        selectedTime != null ? 'Book at $selectedTime' : 'Book Now',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _bookAndWait(
      BuildContext context, DoctorProfile doctor, String specialty, DateTime slotTime) async {
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
      slotTime: slotTime,
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
        resp.data!['appointment_id']?.toString() ??
        (resp.data!['appointment'] is Map ? resp.data!['appointment']['appointmentId']?.toString() : null) ??
        (resp.data!['appointment'] is Map ? resp.data!['appointment']['consultationId']?.toString() : null) ??
        resp.data!['id']?.toString() ?? '';

    if (appointmentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment created but no appointment ID was returned. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
        } else if (index == 2) {
          // Appointments → Calendar
          final api = context.read<DoctorService>().api;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CalendarScreen(api: api)),
          );
        } else if (index == 3) {
          // Profile → pop to dashboard which has profile access
          Navigator.pop(context);
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
