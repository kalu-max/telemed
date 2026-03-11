import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'user_storage_service.dart';
import 'admin_dashboard.dart';
import 'chat_list.dart'; // Importing ChatListScreen
import 'chat_screen.dart';
import 'notifications.dart';
import 'calendar.dart';
import 'video_call_service.dart';
import 'video_call_screen.dart';
import 'patient_list_screen.dart';
import 'prescription_screen.dart';
import 'settings_screen.dart';
import 'config/app_config.dart';

/// Doctor login and dashboard Screen
void main() {
  runApp(const DoctorApp());
}

class DoctorApp extends StatelessWidget {
  const DoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Telemedicine',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DoctorLoginScreen(),
    );
  }
}

/// Doctor Login Screen
class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  bool _obscurePassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Check if user is already logged in and pre-fill email
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final isLoggedIn = await UserStorageService.isUserLoggedIn();
    if (isLoggedIn && mounted) {
      final userEmail = await UserStorageService.getUserEmail();
      if (userEmail != null) {
        setState(() {
          _emailController.text = userEmail;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final api = TeleMedicineApiClient(AppConfig.apiBaseUrl);
    final resp = await api.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!resp.success || resp.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.error?.toString() ?? 'Login failed')),
      );
      return;
    }

    final user = resp.data!['user'];
    final token = resp.data!['token'] as String?;

    if (user == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed: invalid response')),
      );
      return;
    }

    final role = user['role'] as String? ?? '';

    if (role == 'admin') {
      // let admin in
    } else if (role != 'doctor') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account is not a doctor')),
      );
      return;
    }

    api.setAuthToken(token);
    api.currentUserId = user['userId']?.toString();

    // Save user data for persistent login
    try {
      final userId = user['userId']?.toString() ?? '';
      final userName = user['name']?.toString() ?? 'Doctor';
      final userEmail = user['email']?.toString() ?? '';
      
      await UserStorageService.saveUserData(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userRole: role,
        token: token,
        fullUserData: user,
      );
    } catch (e) {
      debugPrint('⚠️ Warning: Failed to save user data: $e');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login successful'),
        backgroundColor: Colors.green,
      ),
    );

    if (!mounted) return;

    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminDashboard(api: api)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorDashboard(api: api),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[50]!, Colors.cyan[50]!],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Doctor Portal\nMediCare Connect',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Manage appointments and conduct teleconsultations',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hintText: 'doctor@example.com',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Password',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    hintText: 'Enter your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DoctorRegisterScreen(),
                      ),
                    );
                  },
                  child: const Text('New doctor? Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------
// Registration screen for doctors
class DoctorRegisterScreen extends StatefulWidget {
  const DoctorRegisterScreen({super.key});

  @override
  State<DoctorRegisterScreen> createState() => _DoctorRegisterScreenState();
}

class _DoctorRegisterScreenState extends State<DoctorRegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedSpecialty = 'Cardiologist';
  bool _obscurePassword = true;

  final List<String> _specialties = [
    'Cardiologist',
    'Dermatologist',
    'Pediatrician',
    'General Practitioner',
    'Orthopedist',
    'Neurologist',
    'Psychiatrist',
    'Urologist',
    'Ophthalmologist',
    'Otolaryngologist',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _selectedSpecialty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final api = TeleMedicineApiClient(AppConfig.apiBaseUrl);
    final resp = await api.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: 'doctor',
      specialization: _selectedSpecialty,
    );

    if (!mounted) return;

    if (!resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.error?.toString() ?? 'Registration failed')),
      );
      return;
    }

    final user = resp.data!['user'];
    final token = resp.data!['token'] as String?;

    if (user == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration error: invalid response')),
      );
      return;
    }

    // Set auth token for auto-login
    api.setAuthToken(token);
    api.currentUserId = user['userId']?.toString();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registered and logged in successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    if (!mounted) return;

    // Navigate directly to dashboard
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorDashboard(api: api),
      ),
    );
  }

  Widget _buildTextFieldForReg({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Registration'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildTextFieldForReg(
                controller: _nameController,
                label: 'Full Name',
                hintText: 'Dr. Alice Smith',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _buildTextFieldForReg(
                controller: _emailController,
                label: 'Email Address',
                hintText: 'doctor@example.com',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline),
                  hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Specialization',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedSpecialty,
                      isExpanded: true,
                      underline: Container(),
                      items: _specialties.map((String specialty) {
                        return DropdownMenuItem<String>(
                          value: specialty,
                          child: Text(specialty),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSpecialty = newValue ?? _specialties.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Register',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

/// Doctor Dashboard
class DoctorDashboard extends StatefulWidget {
  final TeleMedicineApiClient api;

  const DoctorDashboard({super.key, required this.api});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _selectedIndex = 0;

  List<Map<String, dynamic>> _appointments = [];
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;
  int _pendingCount = 0;

  DoctorVideoCallService? _callService;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    _loadProfile();
    _initCallService();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchAppointments();
    });
  }

  Future<void> _initCallService() async {
    final doctorId = widget.api.currentUserId ?? '';
    final userName = await UserStorageService.getUserName() ?? 'Doctor';
    _callService = DoctorVideoCallService(
      serverUrl: AppConfig.apiBaseUrl,
      doctorId: doctorId,
      doctorName: userName,
    );
    await _callService!.initialize();

    _callService!.onIncomingCall = (callId, patientId, patientName) {
      if (!mounted) return;
      _showIncomingCallDialog(patientId, patientName);
    };

    _callService!.onNewAppointment = (apptData) {
      if (!mounted) return;
      _fetchAppointments();
      final name = apptData['patientName']?.toString() ?? 'A patient';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$name is requesting a consultation'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => setState(() => _selectedIndex = 0),
        ),
      ));
    };
  }

  void _showIncomingCallDialog(String patientId, String patientName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Incoming Call'),
        content: Text('$patientName is calling...'),
        actions: [
          TextButton(
            onPressed: () {
              _callService?.rejectCall();
              Navigator.pop(ctx);
            },
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToVideoCall(patientId, patientName, isIncoming: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _navigateToVideoCall(String patientId, String patientName, {bool isIncoming = false}) {
    if (_callService == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorVideoCallScreen(
          callService: _callService!,
          patientId: patientId,
          patientName: patientName,
          isIncoming: isIncoming,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _callService?.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final resp = await widget.api.getAppointments();
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      setState(() {
        _appointments = resp.data!;
        _pendingCount = resp.data!
            .where((a) =>
                a['status'] == 'scheduled' || a['status'] == 'pending')
            .length;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = resp.error?.toString() ?? 'Failed to load appointments';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    if (widget.api.currentUserId == null) return;
    final resp = await widget.api.getDoctorProfile(widget.api.currentUserId!);
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      setState(() {
        _profile = resp.data!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NotificationsScreen(api: widget.api)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.message),
            tooltip: 'Messages',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatListScreen(api: widget.api)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchAppointments,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DoctorLoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? _buildAppointmentsTab()
          : _selectedIndex == 1
              ? PatientListScreen(
                  api: widget.api,
                  onCallPatient: _navigateToVideoCall,
                )
              : _selectedIndex == 2
                  ? _buildProfileTab()
                  : _selectedIndex == 3
                      ? PrescriptionListScreen(api: widget.api)
                      : SettingsScreen(
                          api: widget.api,
                          onLogout: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const DoctorLoginScreen()),
                              (route) => false,
                            );
                          },
                        ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.calendar_today),
                if (_pendingCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Appointments',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Patients',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Prescriptions',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_appointments.isEmpty) {
      return const Center(child: Text('No appointments found'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: const Text('View Calendar'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CalendarScreen(api: widget.api)),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _appointments.length,
            itemBuilder: (context, index) {
              final appt = _appointments[index];
              final patientId = appt['patientId'] ?? 'unknown';
              final patientName = appt['patientName']?.toString() ?? patientId.toString();
              final slotTime = appt['slotTime'] != null
                  ? DateTime.tryParse(appt['slotTime'].toString())
                  : null;
              final slotStr = slotTime != null
                  ? '${slotTime.hour}:${slotTime.minute.toString().padLeft(2, '0')}'
                  : 'time unknown';
              final status = appt['status']?.toString() ?? '';
              final isPending = status == 'scheduled' || status == 'pending';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isPending
                      ? BorderSide(color: Colors.orange[400]!, width: 1.5)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person,
                              color: isPending ? Colors.orange : Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              patientName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPending
                                  ? Colors.orange[50]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isPending
                                    ? Colors.orange[300]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              status.isEmpty ? 'unknown' : status,
                              style: TextStyle(
                                  color: isPending
                                      ? Colors.orange[800]
                                      : Colors.grey[700],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${appt['reason'] ?? ''} • $slotStr',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (isPending)
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.videocam, size: 16),
                                label: const Text('Connect Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                ),
                                onPressed: () async {
                                  final apptId = appt['appointmentId'];
                                  if (apptId != null) {
                                    await widget.api
                                        .updateAppointmentStatus(
                                            apptId, 'connected');
                                  }
                                  final pid = patientId.toString();
                                  if (pid.isNotEmpty && mounted) {
                                    _navigateToVideoCall(pid, patientName);
                                  }
                                },
                              ),
                            )
                          else
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () async {
                                  final apptId = appt['appointmentId'];
                                  final pid = patientId.toString();
                                  if (apptId != null) {
                                    await widget.api
                                        .updateAppointmentStatus(
                                            apptId, 'connected');
                                  }
                                  if (pid.isNotEmpty && mounted) {
                                    _navigateToVideoCall(pid, patientName);
                                  }
                                },
                                child: const Text('Call'),
                              ),
                            ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () async {
                              final pid = patientId.toString();
                              if (pid.isNotEmpty) {
                                final resp = await widget.api.startChat([
                                  widget.api.currentUserId ?? '',
                                  pid
                                ]);
                                if (resp.success &&
                                    resp.data != null &&
                                    resp.data!['chatId'] != null) {
                                  final chatId =
                                      resp.data!['chatId'] as String;
                                  if (mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          api: widget.api,
                                          chatId: chatId,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            child: const Text('Chat'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.cyan[400]!],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 48,
                    color: Colors.blue[600],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add details that patients will see',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctorProfileEditScreen(api: widget.api),
                ),
              ).then((_) {
                // Refresh data after returning from edit screen
                _fetchAppointments();
                _loadProfile();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit),
                SizedBox(width: 8),
                Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildProfileInfoCard(
            icon: Icons.medical_services,
            title: 'Professional Info',
            items: {
              'Specialization': _profile?['specialization'] ?? 'Not set',
              'Qualification': _profile?['qualification'] ?? 'Not set',
              'Experience': _profile?['yearsOfExperience']?.toString() ?? 'Not set',
            },
          ),
          const SizedBox(height: 16),
          _buildProfileInfoCard(
            icon: Icons.attach_money,
            title: 'Service Details',
            items: {
              'Consultation Fee': _profile?['consultationFee'] != null ? '₹${_profile!['consultationFee']}' : 'Not set',
              'Availability': 'Set availability slots',
            },
          ),
          const SizedBox(height: 16),
          _buildProfileInfoCard(
            icon: Icons.info_outline,
            title: 'About You',
            items: {
              'Bio': _profile?['bio'] ?? 'Not set',
              'Languages': 'Add languages you speak',
            },
          ),
          const SizedBox(height: 32),
          // delete account button moved to settings tab
        ],
      ),
    );
  }
  Widget _buildProfileInfoCard({
    required IconData icon,
    required String title,
    required Map<String, String> items,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  Text(
                    e.value,
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

}

// ------------------------------------------------
// Profile edit screen
class DoctorProfileEditScreen extends StatefulWidget {
  final TeleMedicineApiClient api;

  const DoctorProfileEditScreen({super.key, required this.api});

  @override
  State<DoctorProfileEditScreen> createState() => _DoctorProfileEditScreenState();
}

class _DoctorProfileEditScreenState extends State<DoctorProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _qualificationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  String _specialty = '';
  final List<String> _specialties = [
    'Cardiologist',
    'Dermatologist',
    'Pediatrician',
    'General Practitioner',
    'Orthopedist',
    'Neurologist',
    'Psychiatrist',
    'Urologist',
    'Ophthalmologist',
    'Otolaryngologist',
  ];

  bool _loading = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (widget.api.currentUserId == null || widget.api.currentUserId!.isEmpty) {
      setState(() => _initializing = false);
      return;
    }
    final resp = await widget.api.getDoctorProfile(widget.api.currentUserId!);
    if (resp.success && resp.data != null) {
      final data = resp.data!;
      setState(() {
        _bioController.text = data['bio'] ?? '';
        _qualificationController.text = data['qualification'] ?? '';
        _experienceController.text = (data['yearsOfExperience'] ?? '').toString();
        _feeController.text = (data['consultationFee'] ?? '').toString();
        _specialty = data['specialization'] ?? '';
        _initializing = false;
      });
    } else {
      setState(() => _initializing = false);
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final resp = await widget.api.updateDoctorProfile(
      doctorId: widget.api.currentUserId ?? '',
      bio: _bioController.text.trim(),
      qualification: _qualificationController.text.trim(),
      yearsOfExperience: int.tryParse(_experienceController.text.trim()),
      consultationFee: double.tryParse(_feeController.text.trim()),
      specialization: _specialty.isNotEmpty ? _specialty : null,
    );
    setState(() => _loading = false);
    if (resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.error?.toString() ?? 'Update failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _specialty.isNotEmpty ? _specialty : null,
                decoration: const InputDecoration(labelText: 'Specialization'),
                items: _specialties
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _specialty = v ?? ''),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qualificationController,
                decoration: const InputDecoration(labelText: 'Qualification'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _experienceController,
                decoration: const InputDecoration(labelText: 'Years of experience'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _feeController,
                decoration: const InputDecoration(labelText: 'Consultation fee'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _saveProfile,
                child: _loading ? const CircularProgressIndicator() : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}