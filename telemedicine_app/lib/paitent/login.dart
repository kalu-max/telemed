import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'paitentdashboard.dart';
import 'api_client.dart';
import 'admin_dashboard.dart';
import '../communication/services/messaging_service.dart';
import '../services/user_storage_service.dart';
import '../config/app_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isSignUp = false;

  String _selectedGender = 'Male';
  String _selectedBloodType = 'O+';

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _phoneController = TextEditingController();
    _dobController = TextEditingController();
    _addressController = TextEditingController();
    
    // Check if user is already logged in and auto-navigate
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final isLoggedIn = await UserStorageService.isUserLoggedIn();
    if (isLoggedIn && mounted) {
      final userEmail = await UserStorageService.getUserEmail();
      if (userEmail != null) {
        _emailController.text = userEmail;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: const Text('Reset Password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your registered email and choose a new password.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        final newPass = newPassCtrl.text;
                        final confirmPass = confirmPassCtrl.text;

                        if (email.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please fill in all fields')),
                          );
                          return;
                        }
                        if (newPass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password must be at least 6 characters')),
                          );
                          return;
                        }
                        if (newPass != confirmPass) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Passwords do not match')),
                          );
                          return;
                        }

                        setStateDialog(() => isLoading = true);
                        final api = TeleMedicineApiClient(AppConfig.apiBaseUrl);
                        final resp = await api.resetPassword(
                          email: email,
                          newPassword: newPass,
                        );
                        setStateDialog(() => isLoading = false);

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);

                        final success = resp.success;
                        final msg = success
                            ? 'Password reset successfully. Please log in.'
                            : (resp.error ?? 'Reset failed');
                        final color = success ? Colors.green : Colors.red;

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg), backgroundColor: color),
                        );

                        if (success) {
                          _emailController.text = email;
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Reset Password', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      if (!mounted) return;
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
        SnackBar(content: Text(resp.message ?? 'Login failed')),
      );
      return;
    }

    // Get service reference before any async operations
    // ignore: use_build_context_synchronously
    final messagingService = context.read<MessagingService>();

    api.setAuthToken(resp.data!['token']);
    api.currentUserId = resp.data!['user']['userId'] as String? ?? '';
    final role = resp.data!['user']['role'] as String? ?? 'patient';
    final userId = resp.data!['user']['userId'] as String? ?? '';
    final userName = resp.data!['user']['name'] as String? ?? 'Patient';
    final userEmail = resp.data!['user']['email'] as String? ?? '';
    final token = resp.data!['token'] as String? ?? '';

    // Initialize messaging service properties
    messagingService.userId = userId;
    messagingService.userName = userName;

    // Save user data for persistent login
    try {
      await UserStorageService.saveUserData(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userRole: role,
        token: token,
        fullUserData: resp.data!['user'],
      );
    } catch (e) {
      debugPrint('⚠️ Warning: Failed to save user data: $e');
    }

    // Initialize messaging service after login
    try {
      await messagingService.initialize();
    } catch (e) {
      debugPrint('⚠️ Warning: Failed to initialize communication services: $e');
    }

    // build a generic profile for patient dashboard
    final userProfile = UserProfile(
      name: resp.data!['user']['name'] ?? 'User',
      email: resp.data!['user']['email'],
      phone: '+1 (555) 000-0000',
      dateOfBirth: 'unknown',
      gender: _selectedGender,
      bloodType: _selectedBloodType,
      address: 'n/a',
    );

    if (!mounted) return;

    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AdminDashboard(api: api),
        ),
      );
    } else if (role == 'doctor') {
      Navigator.pushReplacementNamed(context, '/doctor/dashboard');
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PatientDashboard(userProfile: userProfile, api: api, userId: userId),
        ),
      );
    }
  }

  void _handleSignUp() {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _dobController.text.isEmpty ||
        _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final userProfile = UserProfile(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      dateOfBirth: _dobController.text,
      gender: _selectedGender,
      bloodType: _selectedBloodType,
      address: _addressController.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account created successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDashboard(userProfile: userProfile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal[50]!, Colors.blue[50]!],
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
                    color: Colors.teal.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    size: 40,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isSignUp
                      ? 'Create Account\nMediCare Connect'
                      : 'Welcome to\nMediCare Connect',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isSignUp
                      ? 'Create an account to get started.'
                      : 'Your health, connected. Sign in to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),

                const SizedBox(height: 20),

                // Sign up only fields
                if (_isSignUp) ...[
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hintText: 'John Doe',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hintText: '+1 (555) 123-4567',
                    icon: Icons.phone_outlined,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _dobController,
                    label: 'Date of Birth (MM/DD/YYYY)',
                    hintText: '01/15/1990',
                    icon: Icons.calendar_today,
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownField(
                    label: 'Gender',
                    value: _selectedGender,
                    items: const ['Male', 'Female', 'Other'],
                    onChanged: (value) {
                      setState(() => _selectedGender = value!);
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownField(
                    label: 'Blood Type',
                    value: _selectedBloodType,
                    items: const ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'],
                    onChanged: (value) {
                      setState(() => _selectedBloodType = value!);
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Address',
                    hintText: '123 Main Street, City, State',
                    icon: Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                ],

                // Email field
                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hintText: 'patient@example.com',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 20),

                // Password field
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

                // Forgot password button
                if (!_isSignUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _showForgotPasswordDialog(),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Login/Sign up button
                ElevatedButton(
                  onPressed: _isSignUp ? _handleSignUp : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isSignUp ? 'Create Account' : 'Sign In',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Toggle sign up/login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp
                          ? 'Already have an account?'
                          : 'Don\'t have an account?',
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _clearFields();
                        });
                      },
                      child: Text(
                        _isSignUp ? 'Sign In' : 'Create Account',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearFields() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _phoneController.clear();
    _dobController.clear();
    _addressController.clear();
    _obscurePassword = true;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
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
          maxLines: maxLines,
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

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
